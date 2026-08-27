#!/usr/bin/env bash
# PreToolUse hook — bloquea comandos peligrosos antes de ejecucion.
# Inspirado en ECC AgentShield + patrones elite 2025-2026.
# Arquitectura: binario-especifico + NO_QUOTES para eliminar falsos positivos.
#
# Contrato de salida:
#   - deny  -> emite permissionDecision "deny" y corta.
#   - resto -> exit 0 SIN stdout. Un "allow" explicito se salta el prompt de
#     permisos, asi que devolverlo por defecto convertia cada comando no listado
#     en auto-aprobado. Silencio = flujo normal de permisos de settings.json.
set -euo pipefail

# jq es obligatorio: sin el, este hook no puede validar comandos peligrosos.
# Fallar cerrado evita que auto/bypassPermissions convierta la ausencia del
# parser en una vía para ejecutar una operación que debía bloquearse.
if ! command -v jq >/dev/null 2>&1; then
  echo "[validate-safe-ops] jq is not installed: blocking preventively; install it with: brew install jq" >&2
  exit 2
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

[ -z "$COMMAND" ] && exit 0

# Modo de permisos de la sesion. Llega en el input de PreToolUse: "default",
# "plan", "acceptEdits", "auto", "dontAsk" o "bypassPermissions".
#
# POR QUE IMPORTA: un hook que devuelve "ask" fuerza un prompt en TODOS los
# modos — bypassPermissions y auto no lo saltan. Devolver "ask" para cosas
# rutinarias (borrar un build, un chmod en un temporal) convertia el modo
# autonomo en un modo que pregunta igual, que es justo lo que el usuario quiso
# desactivar al elegirlo.
#
# Los "deny" NO se tocan: lo catastrofico e irreversible (sudo, curl|bash,
# rm -rf /, DROP TABLE, mkfs, lectura de secretos) bloquea en todos los modos.
# Elegir un modo autonomo es aceptar menos preguntas, no aceptar perder el pie.
PERMISSION_MODE=$(echo "$INPUT" | jq -r '.permission_mode // "default"' 2>/dev/null || echo "default")
AUTONOMOUS=false
case "$PERMISSION_MODE" in
  bypassPermissions | auto) AUTONOMOUS=true ;;
esac

# Resuelve asignaciones simples ANTES de pelar comillas y ANTES de matchear,
# para que `f=.env; cat $f`, `f=.env; cat "$f"` o `b=push; git $b --force` no
# escondan el objetivo detras de un nombre de variable. Todo lo de mas abajo
# lee NO_QUOTES_FULL (HAYSTACK, SEGMENTS), asi que resolver aca una sola vez
# cierra el mismo agujero en todos los checks.
#
# Best-effort, no un parser de shell: solo asignaciones planas `var=valor`
# sin '$' ni backtick en el valor participan — eso ya es indireccion anidada
# y queda fuera de este alcance. Un valor citado con espacios (`x="reset
# --force"`) tampoco se resuelve completo — el detector de asignaciones corta
# en el primer espacio — pero no abre un bypass nuevo: si no resuelve, el
# patron original simplemente no matchea nada, como si la variable no
# existiera. No hace falta ser exhaustivo, alcanza con cerrar el caso simple
# que de verdad se usa para evadir.
resolve_vars() {
  local text="$1" assignments assignment var val safe_val padded
  assignments=$(printf '%s\n' "$text" | grep -oE '\b[A-Za-z_][A-Za-z0-9_]*=[^][:space:];&|]+' || true)
  [ -z "$assignments" ] && {
    printf '%s' "$text"
    return 0
  }
  # Espacio final de centinela: '\b' (word boundary) no existe en BSD sed
  # (macOS) — el mismo problema que ya documenta SEGMENTS mas abajo con \n.
  # Se usa un grupo de captura sobre el caracter siguiente en vez de \b, y el
  # espacio garantiza que ${var} al final del texto tambien tenga un limite
  # con el que matchear.
  padded="$text "
  while IFS= read -r assignment; do
    [ -z "$assignment" ] && continue
    var="${assignment%%=*}"
    val="${assignment#*=}"
    case "$val" in
      *'$'* | *'`'*) continue ;;
    esac
    safe_val=$(printf '%s' "$val" | sed 's/[&/\]/\\&/g')
    # Las formas citadas van PRIMERO y absorben las comillas junto con la
    # referencia: `"$f"` pasa a `.env`, no a `".env"`. Esto tiene que correr
    # ANTES del pelado de comillas de mas abajo (NO_QUOTES_FULL) — si
    # resolviera despues, `"$f"` ya habria perdido su contenido entero al
    # pelar comillas (el patron de comillas no distingue una referencia a
    # variable de un string cualquiera) y no quedaria nada que resolver.
    # Si resolviera antes pero dejara las comillas puestas (`".env"`), el
    # pelado posterior igual las destruye — por eso las comillas se comen
    # aca, no se preservan.
    padded=$(printf '%s' "$padded" | sed -E "s/\"\\\$\\{${var}\\}\"/${safe_val}/g; s/\"\\\$${var}\"/${safe_val}/g; s/'\\\$\\{${var}\\}'/${safe_val}/g; s/'\\\$${var}'/${safe_val}/g")
    padded=$(printf '%s' "$padded" | sed -E "s/\\\$\\{${var}\\}/${safe_val}/g; s/\\\$${var}([^A-Za-z0-9_])/${safe_val}\\1/g")
  done <<<"$assignments"
  printf '%s' "${padded% }"
}
# Corre sobre $COMMAND crudo, no sobre texto ya pelado de comillas — ver el
# comentario dentro de resolve_vars. NO_QUOTES_FULL se reconstruye pelando
# comillas DESPUES de resolver, para que la referencia citada ya haya sido
# consumida y no quede nada que el pelador pueda destruir.
COMMAND_VARS_RESOLVED=$(resolve_vars "$COMMAND")
NO_QUOTES_FULL=$(echo "$COMMAND_VARS_RESOLVED" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

# Resolve the executable after shell command prefixes. This is deliberately a
# small, non-evaluating tokenizer: the hook must never execute user input. It
# skips environment assignments and common wrappers while preserving the real
# command and its arguments for binary-specific checks. Privilege wrappers
# (sudo/doas/su) are intentionally NOT skipped, because the wrapper itself is
# the dangerous operation and must be denied.
AMBIGUOUS_PREFIX_MARKER='__SAFE_OPS_AMBIGUOUS_WRAPPER__'
resolve_command_prefix() {
  local segment="$1" token prefix
  local -a words
  local i=0 n
  # read -a cannot preserve argv boundaries for quoted whitespace. For
  # recognized wrappers, fail closed rather than guessing whether the next
  # logical word is an option value or the real executable.
  if printf '%s' "$segment" | grep -qE '(^|[[:space:]])([^[:space:]]*/)?(env|time|xargs)([[:space:]]|$)' &&
    printf '%s' "$segment" | grep -qE "[\"'][^\"']*[[:space:]][^\"']*[\"']"; then
    printf '%s' "$AMBIGUOUS_PREFIX_MARKER"
    return 0
  fi
  read -r -a words <<<"$segment"
  n=${#words[@]}

  while [ "$i" -lt "$n" ]; do
    token="${words[$i]}"
    # read -a is intentionally not a shell evaluator; normalize only quotes
    # wrapped around a prefix token so `env "sudo" ...` cannot hide it.
    token="${token#\"}"
    token="${token%\"}"
    token="${token#\'}"
    token="${token%\'}"
    words[$i]="$token"
    prefix="${token##*/}"
    case "$prefix" in
      [A-Za-z_][A-Za-z0-9_]*=*)
        # read -a splits an escaped space into two words; consume the
        # continuation so `FOO=a\ b sudo ...` still reaches sudo.
        while [[ "${words[$i]}" == *\\ && "$((i + 1))" -lt "$n" ]]; do
          i=$((i + 1))
        done
        # Quoted assignment values are split by read -a as well; consume all
        # words through the closing quote before resolving the command.
        while [ "$i" -lt "$n" ] && { [[ "${words[$i]}" == *\"* && "${words[$i]}" != *\" ]] || [[ "${words[$i]}" == *\'* && "${words[$i]}" != *\' ]]; }; do
          i=$((i + 1))
        done
        i=$((i + 1))
        ;;
      env)
        i=$((i + 1))
        # env accepts flags and VAR=value pairs before the command.
        while [ "$i" -lt "$n" ]; do
          token="${words[$i]}"
          token="${token#\"}"
          token="${token%\"}"
          token="${token#\'}"
          token="${token%\'}"
          words[$i]="$token"
          case "$token" in
            --)
              i=$((i + 1))
              break
              ;;
            -u | --unset) i=$((i + 2)) ;;
            -i | -0 | --ignore-environment) i=$((i + 1)) ;;
            [A-Za-z_][A-Za-z0-9_]*=*) i=$((i + 1)) ;;
            -*) i=$((i + 1)) ;;
            *) break ;;
          esac
        done
        ;;
      nohup)
        i=$((i + 1))
        [ "$i" -lt "$n" ] && [ "${words[$i]}" = "--" ] && i=$((i + 1))
        ;;
      command)
        i=$((i + 1))
        while [ "$i" -lt "$n" ] && [[ "${words[$i]}" == -* ]]; do
          i=$((i + 1))
        done
        ;;
      time)
        i=$((i + 1))
        # GNU/BSD time options precede the command; -o/--output consume a
        # filename while flags such as -l are standalone.
        while [ "$i" -lt "$n" ] && [[ "${words[$i]}" == -* ]]; do
          if [ "${words[$i]}" = "-o" ] || [ "${words[$i]}" = "--output" ]; then
            i=$((i + 2))
          else
            i=$((i + 1))
          fi
        done
        ;;
      nice)
        i=$((i + 1))
        if [ "$i" -lt "$n" ] && [ "${words[$i]}" = "-n" ]; then
          i=$((i + 2))
        elif [ "$i" -lt "$n" ] && [[ "${words[$i]}" =~ ^-[0-9]+$ ]]; then
          i=$((i + 1))
        fi
        ;;
      xargs)
        i=$((i + 1))
        # Skip xargs options, including options that consume one value.
        while [ "$i" -lt "$n" ]; do
          token="${words[$i]}"
          case "$token" in
            --)
              i=$((i + 1))
              break
              ;;
            -n | -P | -L | -I | -d | -E | -a | --max-args | --max-procs | --max-lines | --replace | --delimiter | --eof | --arg-file) i=$((i + 2)) ;;
            -*) i=$((i + 1)) ;;
            *) break ;;
          esac
        done
        ;;
      stdbuf)
        i=$((i + 1))
        while [ "$i" -lt "$n" ] && [[ "${words[$i]}" == -* ]]; do
          token="${words[$i]}"
          # stdbuf's -i/-o/-e options may be attached or separate.
          if [[ "$token" == "-i" || "$token" == "-o" || "$token" == "-e" ]]; then
            i=$((i + 2))
          else
            i=$((i + 1))
          fi
        done
        ;;
      timeout)
        i=$((i + 1))
        # Skip timeout flags and their values, then its duration.
        while [ "$i" -lt "$n" ]; do
          token="${words[$i]}"
          case "$token" in
            --)
              i=$((i + 1))
              break
              ;;
            -k | --kill-after | --signal) i=$((i + 2)) ;;
            -*) i=$((i + 1)) ;;
            *)
              i=$((i + 1))
              break
              ;;
          esac
        done
        ;;
      sudo | doas | su)
        # Elevation is itself a deny; leave this token as the binary.
        break
        ;;
      *)
        break
        ;;
    esac
  done

  printf '%s' "${words[*]:i}"
}

# Raw quoted arguments need a reader-aware check. Stripping all quoted text is
# useful for avoiding prose false positives, but it must not erase a quoted
# secret path from an actual cat/rg/head/... command. Nested -c payloads are
# inspected recursively without eval.
check_raw_segment() {
  local segment="$1" normalized head binary nested
  normalized=$(resolve_command_prefix "$segment")
  if [ "$normalized" = "$AMBIGUOUS_PREFIX_MARKER" ]; then
    deny "Ambiguous quoted whitespace after a command wrapper is blocked. Use unquoted wrapper options and a separately named command."
  fi
  [ -z "$normalized" ] && return 0
  head=$(printf '%s' "$normalized" | awk '{print $1}')
  binary="${head##*/}"

  case "$binary" in
    cat | bat | head | tail | less | more | nl | od | xxd | strings | base64 | cp | mv | rsync | scp | open | source | . | rg | grep | ag | ack | awk | sed | sd)
      # Versioned templates are intentionally readable.
      if printf '%s ' "$segment" | grep -qE "$IS_TEMPLATE"; then
        return 0
      fi
      if printf '%s ' "$segment" | grep -qE "[[:space:]][^[:space:]|;&]*${SECRET_NAME}([[:space:]]|[\"']|;|&|\\|)" ||
        printf '%s ' "$segment" | grep -qE "${PROTECTED_HOME_PATH}|${PROTECTED_RELATIVE_PATH}"; then
        deny "Reading secrets through the shell is blocked, including quoted paths. Use a redacted fixture or an environment variable."
      fi
      if [ "$binary" = awk ] && printf '%s' "$segment" | grep -qE 'system[[:space:]]*\('; then
        deny "awk system() execution is blocked. It can execute arbitrary commands from a quoted program."
      fi
      ;;
    sudo | doas | su | mkfs | mkfs.* | newfs | newfs_msdos)
      deny "Dangerous command execution through a quoted or nested payload is blocked."
      ;;
    bash | sh | zsh | dash | fish | python | python3 | perl | ruby | node | nodejs)
      if printf '%s' "$segment" | grep -qE '(os\.system|os\.popen|subprocess\.(run|call|Popen)|child_process\.)'; then
        deny "Arbitrary command execution from a quoted interpreter payload is blocked."
      fi
      if printf '%s' "$normalized" | grep -qE '(^|[[:space:]])(-c|--command)(=|[[:space:]])'; then
        nested=$(printf '%s' "$normalized" | sed -E 's/^[^[:space:]]+[[:space:]]+(-c|--command)(=|[[:space:]])//')
        nested="${nested#\"}"
        nested="${nested%\"}"
        nested="${nested#\'}"
        nested="${nested%\'}"
        [ -n "$nested" ] && analyze_canonical_command "$nested"
      fi
      ;;
  esac
}

# A pending ask is emitted only after every deny rule has inspected the full
# command. This prevents an early, routine ask (for example git clean) from
# hiding a catastrophic deny in a later compound-command segment.
ASK_REASON=""

# DOS NIVELES, a proposito.
#
#   deny — catastrofico e irreversible. No hay razon legitima para correrlo
#          desde una sesion de agente. Sin escape: si de verdad lo necesitas,
#          lo haces vos en tu terminal.
#   ask  — destructivo pero rutinario. Borrar un build, un node_modules, un
#          directorio temporal. Denegarlo de plano te obligaba a salirte de la
#          sesion para trabajar, y un guardarrail que estorba termina esquivado.
#          El usuario decide en el momento, con el comando a la vista.
deny() {
  jq -nc --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
}

ask() {
  # Do not terminate here: a later segment may contain a deny. Keep the first
  # ask reason and emit it at the end, after all deny rules have run.
  if [ -z "$ASK_REASON" ]; then
    ASK_REASON="$1"
    # En modo autonomo el prompt no aporta: el usuario ya declaro que no quiere
    # que le pregunten por esto. Queda el aviso en stderr, que el agente si lee.
    if [ "$AUTONOMOUS" = true ]; then
      echo "[validate-safe-ops] ($PERMISSION_MODE) $1" >&2
    fi
  fi
  return 0
}

# === UNIVERSAL — comando completo (patrones RCE y destruccion multi-linea) ===

# Pipe a bash (RCE classico)
if echo "$NO_QUOTES_FULL" | grep -qE 'curl.*\|.*(bash|sh|zsh)'; then
  deny "curl | bash blocked. Download the script, review it, and run it separately."
fi
if echo "$NO_QUOTES_FULL" | grep -qE 'wget.*-O\s*-\s*.*\|.*(bash|sh|zsh)'; then
  deny "wget | bash blocked. Download the script, review it, and run it separately."
fi

# DROP TABLE via echo/printf pipe (patron multi-comando)
if echo "$NO_QUOTES_FULL" | grep -qiE '(echo|printf|cat).*\bDROP\s+(TABLE|DATABASE|SCHEMA)\b.*\|'; then
  deny "DROP TABLE via pipe blocked. Run it manually if it is intentional."
fi

# Lectura de secretos por shell.
# permissions.deny de settings.json cubre el tool Read, pero NO cubre Bash:
# 'cat .env' esquivaba la regla entera, y cat/head/tail/bat/rg/grep estan todos
# en permissions.allow. Se bloquea el binario de lectura apuntando al archivo,
# no el nombre suelto: 'git diff .env' o 'echo .env' no son fugas.
#
# El centinela ' ' al final NO es cosmetico: en ERE de BSD (macOS) un '$' dentro
# de un grupo alternado, '(...|$|...)', no es ancla de fin de linea sino un '$'
# literal, asi que 'cat .env' (sin nada despues) nunca matcheaba y el bloqueo
# entero era un no-op silencioso. Con el espacio agregado, el cierre se expresa
# solo con separadores reales y el patron se porta igual en BSD y GNU.
HAYSTACK="$NO_QUOTES_FULL "
SECRET_NAME='(\.env(\.[a-zA-Z0-9_-]+)?|credentials\.json|id_rsa|id_ed25519|id_ecdsa|[^[:space:]]*\.(pem|key|ppk|p12|pfx|pvk))'
SECRET_ARG="[[:space:]][^[:space:]|;&]*${SECRET_NAME}([[:space:]]|;|&|\\|)"
# Explicit settings.deny paths need a second, raw-command check. The generic
# reader rule intentionally strips quoted strings to avoid documentation false
# positives, but that also erased `cat "$HOME/.aws/credentials"`. These paths
# are never safe to inspect through Bash, whether addressed by tilde, HOME, or
# a relative secrets directory. The payloads are only strings; no path is
# opened here.
# Include the literal resolved home path as well as shell aliases. Escape the
# path for ERE without invoking a shell or resolving any user-provided text.
HOME_REGEX=${HOME//\\/\\\\}
HOME_REGEX=${HOME_REGEX//./\\.}
HOME_REGEX=${HOME_REGEX//\//\\/}
PROTECTED_HOME_PATH="(~|\\\$HOME|\\\$\\{HOME\\}|${HOME_REGEX})/(\\.aws/credentials|\\.config/gh/hosts\\.yml|\\.netrc|\\.npmrc|\\.docker/config\\.json|\\.kube/config|\\.gnupg)(/|[[:space:]]|[\"';|&]|$)"
PROTECTED_RELATIVE_PATH="((\\./|\\.\\./)*secrets/[^[:space:]\"';|&]+)"
PROTECTED_READER="(^|[;&|])[[:space:]]*(cat|rg|head|tail|grep|awk)[[:space:]]+[^;&|]*"
if printf '%s' "$COMMAND_VARS_RESOLVED" | grep -qE \
  "${PROTECTED_READER}(${PROTECTED_HOME_PATH}|${PROTECTED_RELATIVE_PATH})"; then
  deny "Bash reading a protected credential path is blocked, including tilde, HOME, and relative secrets/** aliases. Use a redacted fixture or an explicitly named non-secret variable."
fi
# Plantillas versionadas: '.env.example' se commitea a proposito y no contiene
# nada. Bloquearlo solo entrena a esquivar el hook.
IS_TEMPLATE='\.(example|sample|template|dist|defaults?)([[:space:]]|;|&|\|)'

# Volcado del entorno.
#
# Idea tomada de la config de Codex, que trae `shell_environment_policy.exclude`
# con *_KEY, *_SECRET, *_TOKEN, *_PASSWORD, *_CREDENTIAL*: filtra esas variables
# ANTES de que el shell del agente las vea. Claude Code no tiene equivalente.
#
# Es el hermano del bloqueo de 'cat .env' de mas arriba: ahi se tapa el archivo,
# aca el entorno ya cargado. Sin esto, un `env` o un `echo $X_TOKEN` volcaba lo
# mismo que el archivo que si estaba protegido — con `Bash(env:*)`, `Bash(echo:*)`
# y `Bash(export:*)` los tres en permissions.allow.
#
# Se bloquea el VOLCADO, no el uso: `env VAR=1 cmd` (asignacion) y `export PATH=...`
# son trabajo normal y siguen pasando.
ENV_DUMP='(^|[|;&]|&&)[[:space:]]*(env|printenv)[[:space:]]*([|;&]|$)'
ENV_DUMP_FLAGS='(^|[|;&])[[:space:]]*(export[[:space:]]+-p|declare[[:space:]]+-x|set)[[:space:]]*([|;&]|$)'
SENSITIVE_VAR='\$\{?[A-Za-z_][A-Za-z0-9_]*(_KEY|_SECRET|_TOKEN|_PASSWORD|_PASSWD|_CREDENTIALS?|_APIKEY)\b'

if echo "$HAYSTACK" | grep -qE "$ENV_DUMP" || echo "$HAYSTACK" | grep -qE "$ENV_DUMP_FLAGS"; then
  deny "Environment dump blocked. 'env'/'printenv'/'export -p' print ALL variables, including the tokens currently loaded. If you need a specific variable, name it; if you need to know whether it exists, use: [ -n \"\${VAR:-}\" ] && echo defined."
fi

# IMPRIMIR un secreto se bloquea; USARLO no.
#
# `curl -H "auth: $TOKEN"` es el caso de uso legitimo y tiene que pasar.
# `echo "$TOKEN"` es una fuga a stdout, al transcript y a cualquier log.
#
# Se evalua sobre $COMMAND y NO sobre $HAYSTACK: HAYSTACK viene del strip de
# strings quoted, y `echo "$API_KEY"` — con comillas, que es la forma correcta
# de escribir bash y por lo tanto la mas probable — quedaba en `echo ` y no
# matcheaba nada. La version sin comillas se bloqueaba y la peligrosa pasaba.
PRINTERS='(echo|printf|print|cat|tee|head|tail|write|logger|say)'
if echo "$COMMAND" | grep -qE "\b${PRINTERS}\b[^|;&]*${SENSITIVE_VAR}"; then
  deny "Printing a secret-named variable is blocked (*_KEY, *_SECRET, *_TOKEN, *_PASSWORD, *_CREDENTIAL). It goes to stdout, to the transcript and to the logs. Pass it straight to the command that needs it — 'curl -H \"auth: \$TOKEN\"' is allowed — or only check whether it exists: [ -n \"\${VAR:-}\" ] && echo defined."
fi

if ! echo "$HAYSTACK" | grep -qE "$IS_TEMPLATE"; then
  if echo "$HAYSTACK" | grep -qE "\b(cat|bat|head|tail|less|more|nl|od|xxd|strings|base64|cp|mv|rsync|scp|open|source|\.)\b[^|;&]*${SECRET_ARG}"; then
    deny "Reading secrets through the shell is blocked (.env, credentials.json, private keys, certs). The settings.json deny only covers the Read tool; this closes the same hole through Bash. If you need a variable, read it from the environment, not from the file."
  fi
  if echo "$HAYSTACK" | grep -qE "\b(rg|grep|ag|ack|awk|sed|sd)\b[^|;&]*${SECRET_ARG}"; then
    deny "Grep/sed over a secrets file is blocked. Use the variable name from the environment, not the file contents."
  fi
fi

# Operaciones de esquema por ORM.
#
# EL CASO: un agente corrio `prisma migrate diff ... --shadow-database-url
# $DATABASE_URL_UNPOOLED` y vacio una Supabase de produccion en 10 minutos. La
# shadow database es descartable y Prisma la RESETEA; la variable apuntaba a
# produccion. El agente detecto el daño solo y lo reporto — despues.
#
# POR QUE NO ALCANZABA LO QUE HABIA: se bloqueaba `DROP TABLE`, que es obvio.
# `migrate diff` se lee como una comparacion inofensiva. El peligro no estaba en
# el verbo sino en A DONDE APUNTABA. Una blocklist de comandos siempre va un
# incidente atras, porque el proximo se va a llamar distinto.
#
# QUE HACE ESTE BLOQUE: no le prohibe al agente tocar el esquema. Le exige
# CORROBORAR el destino antes, que es lo unico que hubiera evitado el caso. Si
# el destino es un host remoto o una variable sin resolver, para y lo dice.
ORM_SCHEMA='(prisma|drizzle-kit|sequelize(-cli)?|typeorm|knex|alembic|atlas)\b'
# `db push` a secas NO entra: contra local es el ciclo de desarrollo normal, y
# bloquearlo empuja a desactivar el hook entero. Lo que entra es el verbo que
# borra siempre, o el flag que existe justamente para autorizar perder datos.
ORM_DESTRUCTIVE='(migrate[[:space:]]+(reset|fresh)|push[^|;&]*--force|--force-reset|--accept-data-loss|schema:drop|db:drop|db:reset|migrate:fresh|migrate:refresh|downgrade[[:space:]]+base)'
ARTISAN_RAILS='(artisan[[:space:]]+migrate:(fresh|refresh|reset)|rails[[:space:]]+db:(drop|reset)|rake[[:space:]]+db:(drop|reset))'

# Destino remoto = cualquier DSN que no sea local. Es la señal que faltaba.
REMOTE_DSN='(postgres(ql)?|mysql|mongodb(\+srv)?|redis)://[^[:space:]]*'
LOCAL_HOST='(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\]|host\.docker\.internal)'

# El cuerpo de un heredoc son DATOS, no comandos. Sin sacarlo, escribir
# documentacion sobre estos comandos disparaba el bloqueo: un `python3 <<'EOF'`
# que contenia el ejemplo del incidente quedaba bloqueado como si lo estuviera
# ejecutando. Tercera vez hoy que el mismo error aparece — matchear texto citado
# como si fuera ejecutable.
# Solo se recorta para las reglas de ORM. Lo catastrofico (sudo, rm -rf /,
# curl|bash) sigue evaluandose sobre el comando completo, porque ahi un heredoc
# a `bash` SI seria ejecucion real.
#
# Tres etapas, en este orden, y el orden importa:
#
#   1. Recortar el cuerpo del heredoc SOBRE $COMMAND CRUDO, tolerando un
#      delimitador citado (`<<'EOF'`, `<<"EOF"`). Si esto corriera despues
#      del pelado de comillas, `<<'EOF'` ya habria perdido el 'EOF' entero
#      (el pelador de comillas no distingue un delimitador citado de un
#      string comun) y el heredoc dejaria de detectarse — el cuerpo entero
#      se colaba sin recortar. Bug real, lo probe antes de este comentario.
#   2. Pelar comillas DESPUES: `git commit -m "fix: prisma migrate reset
#      docs"` no debe disparar el bloqueo — mismo problema que el heredoc,
#      con comillas en vez de heredoc.
#   3. Resolver variables (resolve_vars) al final, para que `x=reset; prisma
#      migrate $x --force` no se escape de estas reglas. Se resuelve aparte
#      de NO_QUOTES_FULL: ese ya paso por resolve_vars ANTES del recorte de
#      heredoc, con lo cual un heredoc citado ya viene destruido cuando
#      resolve_vars actua sobre el.
#
# El awk anterior tenia ademas tres bugs de verdad, no cosmeticos:
#   - `next` en la linea de apertura descartaba esa linea ENTERA, incluido el
#     comando que la precede a `<<EOF` — `prisma migrate diff ... <<EOF`
#     desaparecia por completo, exactamente el caso del incidente.
#   - el cierre exigia `^[A-Za-z_]+$` (sin digitos): un delimitador como
#     `<<EOF1` nunca cerraba y todo lo que seguia quedaba recortado para
#     siempre.
#   - `<<` tambien es shift aritmetico (`$((a<<b))`): sin distinguirlo,
#     cualquier `a<<b` abria un heredoc fantasma que tapaba el resto del
#     comando.
# Este awk imprime la linea de apertura, captura el delimitador real (con o
# sin comillas, letras y digitos) y lo usa para el cierre, y no trata `<<`
# como heredoc si esta dentro de un `$((` sin cerrar todavia.
ORM_NO_HEREDOC=$(printf '%s' "$COMMAND" | awk '
  inhd {
    if ($0 == delim) { inhd = 0 }
    next
  }
  match($0, /<<-?["'"'"']?[A-Za-z_][A-Za-z0-9_]*["'"'"']?/) {
    before = substr($0, 1, RSTART - 1)
    n_open = gsub(/\$\(\(/, "&", before)
    n_close = gsub(/\)\)/, "&", before)
    if (n_open > n_close) { print; next }
    delim = substr($0, RSTART, RLENGTH)
    gsub(/^<<-?["'"'"']?|["'"'"']?$/, "", delim)
    inhd = 1
    print
    next
  }
  { print }
')
ORM_HAYSTACK=$(printf '%s' "$ORM_NO_HEREDOC" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")
ORM_HAYSTACK=$(resolve_vars "$ORM_HAYSTACK")

if echo "$ORM_HAYSTACK" | grep -qEi "$ORM_SCHEMA" || echo "$ORM_HAYSTACK" | grep -qEi "$ARTISAN_RAILS"; then
  # Se usa ORM_HAYSTACK y NO se reasigna COMMAND: mas abajo el bloque de
  # clientes de DB busca DROP TABLE sobre el comando ORIGINAL, y pisarlo aca
  # dejaba esa regla mirando un texto ya recortado.

  # 1. Verbo destructivo sin vuelta atras.
  if echo "$ORM_HAYSTACK" | grep -qEi "$ORM_DESTRUCTIVE" || echo "$ORM_HAYSTACK" | grep -qEi "$ARTISAN_RAILS"; then
    deny "Destructive schema operation blocked. These commands drop or empty tables even when the name does not say so. Before running it by hand: (1) confirm which database the connection points to, (2) verify a restorable backup exists, (3) declare the blast radius to the user. See rules/common/destructive-operations.md."
  fi

  # 2. Destino remoto explicito en cualquier operacion de esquema.
  if echo "$ORM_HAYSTACK" | grep -qEi "$REMOTE_DSN"; then
    if ! echo "$ORM_HAYSTACK" | grep -qEi "://[^[:space:]@]*(@)?${LOCAL_HOST}"; then
      deny "Schema operation targeting a REMOTE host. This is how a production database got wiped: the command looked harmless and the URL pointed at prod. Run the schema against local, or ask the user to run it themselves against that host."
    fi
  fi

  # 3. Destino en una variable sin resolver: no se puede saber a donde apunta.
  # Este es EXACTAMENTE el caso del incidente ($DATABASE_URL_UNPOOLED).
  if echo "$ORM_HAYSTACK" | grep -qE '(--[a-z-]*(database-)?url[= ]|DATABASE_URL[A-Z_]*=)[^[:space:]]*\$'; then
    deny "The target of this schema operation comes from an unresolved variable, so neither you nor the hook knows which database it points to. That is the exact case that wiped a production Supabase: --shadow-database-url received a variable pointing at prod, and the shadow database is reset by design. VERIFY first where it resolves to (without printing credentials) and say so before running anything."
  fi
fi

# Destruccion de filesystem — sobre el comando COMPLETO: limitarlo a la primera
# linea dejaba pasar 'echo ok' seguido de 'rm -rf /'.
RM_RECURSIVE='\brm\s+(-[a-zA-Z]*\s+)*-?[a-zA-Z]*r[a-zA-Z]*f|\brm\s+(-[a-zA-Z]*\s+)*-?[a-zA-Z]*f[a-zA-Z]*r'
if echo "$NO_QUOTES_FULL" | grep -qE "$RM_RECURSIVE"; then
  # Solo el objetivo decide el nivel. Borrar la raiz o el home no se negocia;
  # borrar un build o un directorio temporal es trabajo normal.
  # shellcheck disable=SC2016
  # The regex intentionally matches literal $HOME text.
  if echo "$NO_QUOTES_FULL" | grep -qE '\brm\s+(-[a-zA-Z]+\s+)+(/|/\*|~|~/|~/\*|\$HOME|\$HOME/|\$HOME/\*)(\s|$|;|&)'; then
    deny "rm -rf over the root or the home directory is blocked. It is irreversible and there is no legitimate reason to run it from an agent session."
  fi
  ask "rm -rf is irreversible. Review the exact path before approving."
fi

# Borrar un test por Bash. protect-tests.sh solo ve Edit|Write|NotebookEdit, y la
# regla de arriba solo mira `rm -rf`: un `rm tests/foo.test.ts` pelado no lo veia
# NADIE. Ese es exactamente el caso que motivo protect-tests.sh — un agente que
# borra sus propios tests durante un refactor porque estorbaban.
# Es `ask`, no `deny`: borrar un test obsoleto es legitimo, pero lo autoriza el
# usuario (Hard Rule 8), no el agente por su cuenta.
# `\brm\b` y no `\brm\s+`: con \s+ el espacio posterior a rm quedaba consumido y
# el separador que exigen las alternativas de abajo ya no estaba disponible, asi
# que `rm test_login.py` (el argumento pegado al comando) se escapaba entero.
RM_TEST='\brm\b[^|;&]*((\.|_)(test|spec)\.|[[:space:]/]test_|[[:space:]/](tests?|specs?|__tests__|__snapshots__|features|e2e)/|(Test|Tests|Spec)\.(java|kt|cs|scala|php|swift)|\.(snap|ambr|feature)([[:space:]]|$))'
if echo "$NO_QUOTES_FULL" | grep -qE "$RM_TEST"; then
  ask "You are deleting test coverage. Hard Rule 8: a test is not removed to make the code pass. If the requirement genuinely changed, state which test, why, and what stays covered afterwards."
fi

if echo "$NO_QUOTES_FULL" | grep -qE '\bchmod\s+(-R\s+)?777\b'; then
  ask "chmod 777 makes the file writable by anyone. Approve it only for a throwaway directory; otherwise use 644/755/700."
fi

# === BINARY-SPECIFIC ===
#
# Un comando trae varios binarios: 'cd repo && git push --force' arrancaba con
# 'cd', asi que el case de git no se evaluaba nunca. Se parte por los operadores
# de shell y se revisa CADA segmento.
# awk en vez de sed porque BSD sed (macOS) no interpreta \n en el reemplazo.
SEGMENTS=$(printf '%s' "$NO_QUOTES_FULL" | awk '{gsub(/&&|\|\||\||;/, "\n"); print}')

check_segment() {
  local segment="$1" normalized head binary
  normalized=$(resolve_command_prefix "$segment")
  if [ "$normalized" = "$AMBIGUOUS_PREFIX_MARKER" ]; then
    deny "Ambiguous quoted whitespace after a command wrapper is blocked. Use unquoted wrapper options and a separately named command."
  fi
  [ -z "$normalized" ] && return 0
  segment="$normalized"
  head=$(printf '%s' "$segment" | awk '{print $1}')
  [ -z "$head" ] && return 0
  binary="${head##*/}"

  case "$binary" in
    sudo | doas | su)
      deny "Privilege escalation through sudo/doas/su is blocked. Run without elevated privileges."
      ;;
    git)
      # --force($|[^-]) = --force al final o seguido de espacio (no --force-with-lease)
      if echo "$segment" | grep -qE '\bpush\b.*--force($|[^-])'; then
        deny "git push --force blocked. Use --force-with-lease if it is necessary."
      fi
      if echo "$segment" | grep -qE '\bpush\b.*(\s-f\b|^-f\b)'; then
        deny "git push -f blocked. Use --force-with-lease if it is necessary."
      fi
      # Un refspec con "+" delante es un force push sin la palabra force:
      # `git push origin +main` sobrescribe el remoto igual que --force. Sin
      # esta linea, la regla de arriba se esquiva escribiendo el mismo efecto
      # de otra forma, que es el modo de falla de validar un CLI por su texto.
      if echo "$segment" | grep -qE '\bpush\b.*[[:space:]]\+[A-Za-z0-9_./-]+(:|$|[[:space:]])'; then
        deny "git push with a '+' refspec is a force push. Use --force-with-lease if it is necessary."
      fi
      if echo "$segment" | grep -qE '\breset\s+.*--hard(\s|$)'; then
        deny "git reset --hard blocked. Use git stash or git checkout -- <file> for selective discards."
      fi
      # Descartan trabajo no commiteado, pero son parte del dia a dia: decide el usuario.
      if echo "$segment" | grep -qE '\bclean\b.*-[a-zA-Z]*[fdx]'; then
        ask "git clean deletes untracked files irreversibly. Review 'git clean -n' before approving."
      fi
      if echo "$segment" | grep -qE '\bcheckout\b.*(\s-f\b|--force\b)'; then
        ask "git checkout -f discards local changes with no backup. Approve it only if you know nothing is lost."
      fi
      ;;
    npm)
      # -g standalone — evita falsos positivos con paquetes que terminan en -g.
      # Las tres formas son el mismo install global: npm acepta -g, --global y
      # --location=global. Validar solo la corta deja las otras dos abiertas.
      if echo "$segment" | grep -qE '\b(install|i)\b.*(\s-g(\s|$)|^-g(\s|$)|--global(\s|$)|--location=global(\s|$))'; then
        deny "npm global install blocked. Use npx for one-shot tools."
      fi
      ;;
    pip | pip3)
      if echo "$segment" | grep -qE '\binstall\b.*--break-system-packages'; then
        deny "pip install --break-system-packages blocked. It bypasses the venv protection. Use a venv or uv."
      fi
      ;;
    kubectl)
      if echo "$segment" | grep -qE '^\s*kubectl\s+delete\b'; then
        deny "kubectl delete blocked. Destructive operation on the cluster."
      fi
      ;;
    helm)
      if echo "$segment" | grep -qE '^\s*helm\s+(uninstall|delete)\b'; then
        deny "helm uninstall/delete blocked. Destructive operation on the cluster."
      fi
      ;;
    terraform)
      if echo "$segment" | grep -qE '\bterraform\s+destroy\b|\bterraform\s+apply\b.*-auto-approve'; then
        deny "terraform destroy/apply -auto-approve blocked. Infrastructure as code requires manual review."
      fi
      ;;
    mysql | psql | sqlite3 | mongo | mongosh | redis-cli | mariadb | cockroach | sqlplus | duckdb | clickhouse-client | bq | snowsql | mysqlsh)
      # Sobre el comando original (con quotes): el DROP suele ir dentro de -e "..." o -c "..."
      if echo "$COMMAND" | grep -qiE '\bDROP\s+(TABLE|DATABASE|SCHEMA)\b'; then
        deny "DROP TABLE/DATABASE blocked. Run it manually if it is intentional."
      fi
      ;;
    dd)
      # of= es el lado que DESTRUYE: `dd of=/dev/rdisk0` sobrescribe el disco
      # sin necesitar if=. Validar solo la entrada dejaba pasar exactamente la
      # mitad peligrosa del comando.
      if echo "$segment" | grep -qE '\b(if|of)='; then
        deny "dd blocked. Dangerous low-level operation."
      fi
      ;;
    mkfs | mkfs.* | newfs | newfs_msdos)
      deny "mkfs/newfs blocked. Formatting a filesystem is irreversible without a backup."
      ;;
  esac
}

# Canonical analyzer: preserve quoted arguments and command names, split only
# shell operators outside quotes, and run raw plus binary-specific checks. The
# same function is used for top-level input and nested -c payloads.
analyze_canonical_command() {
  local command="$1" raw_segments raw_segment
  if printf '%s' "$command" | grep -qE "(curl.*\\|[[:space:]]*|wget.*-O[[:space:]]*-[^|]*\\|[[:space:]]*)[\"']?(bash|sh|zsh)[\"']?"; then
    deny "Piping a remote script to a shell is blocked. Download it, review it, and run it separately."
  fi
  raw_segments=$(printf '%s' "$command" | awk '
    {
      out = ""; single = 0; double = 0; escaped = 0
      for (i = 1; i <= length($0); i++) {
        ch = substr($0, i, 1)
        if (escaped) { out = out ch; escaped = 0; continue }
        if (ch == "\\\\" && !single) { out = out ch; escaped = 1; continue }
        if (ch == "\"" && !single) { double = !double; out = out ch; continue }
        if (ch == "\047" && !double) { single = !single; out = out ch; continue }
        if (!single && !double && (ch == ";" || ch == "|" || ch == "&")) {
          if (length(out)) print out
          out = ""
          continue
        }
        out = out ch
      }
      if (length(out)) print out
    }
  ')
  while IFS= read -r raw_segment; do
    check_raw_segment "$raw_segment"
    check_segment "$raw_segment"
  done <<<"$raw_segments"
}

analyze_canonical_command "$COMMAND_VARS_RESOLVED"

while IFS= read -r segment; do
  check_segment "$segment"
done <<<"$SEGMENTS"

# Emit a deferred ask only after every deny rule has inspected every segment.
if [ -n "$ASK_REASON" ] && [ "$AUTONOMOUS" != true ]; then
  jq -nc --arg reason "$ASK_REASON" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
fi

# Sin hallazgos: no opinamos. El flujo de permisos de settings.json decide.
exit 0

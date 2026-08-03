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

# jq es obligatorio: sin el, este hook no puede leer el input y falla ABIERTO.
# Se avisa fuerte en vez de morir en silencio, porque un hook mudo parece un
# hook que aprueba. Instalar: brew install jq / apt install jq.
if ! command -v jq >/dev/null 2>&1; then
  echo "[validate-safe-ops] jq no esta instalado: los comandos peligrosos NO se estan validando. Instalalo con: brew install jq" >&2
  exit 0
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

# Comando sin strings quoted — evita falsos positivos en mensajes de commit/heredocs
NO_QUOTES_FULL=$(echo "$COMMAND" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

# Resuelve asignaciones simples ANTES de matchear, para que `f=.env; cat $f`
# o `b=push; git $b --force` no escondan el objetivo detras de un nombre de
# variable. Todo lo de mas abajo lee NO_QUOTES_FULL (HAYSTACK, SEGMENTS), asi
# que resolver aca una sola vez cierra el mismo agujero en todos los checks.
#
# Best-effort, no un parser de shell: solo asignaciones planas `var=valor`
# sin '$' ni backtick en el valor participan — eso ya es indireccion anidada
# y queda fuera de este alcance. No hace falta ser exhaustivo, alcanza con
# cerrar el caso simple que de verdad se usa para evadir.
resolve_vars() {
  local text="$1" assignments assignment var val safe_val padded
  assignments=$(printf '%s\n' "$text" | grep -oE '\b[A-Za-z_][A-Za-z0-9_]*=[^][:space:];&|]+' || true)
  [ -z "$assignments" ] && { printf '%s' "$text"; return 0; }
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
    padded=$(printf '%s' "$padded" | sed -E "s/\\\$\\{${var}\\}/${safe_val}/g; s/\\\$${var}([^A-Za-z0-9_])/${safe_val}\\1/g")
  done <<< "$assignments"
  printf '%s' "${padded% }"
}
NO_QUOTES_FULL=$(resolve_vars "$NO_QUOTES_FULL")

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
  # En modo autonomo el prompt no aporta: el usuario ya declaro que no quiere
  # que le pregunten por esto. Queda el aviso en stderr, que el agente si lee.
  if [ "$AUTONOMOUS" = true ]; then
    echo "[validate-safe-ops] ($PERMISSION_MODE) $1" >&2
    exit 0
  fi
  jq -nc --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  exit 0
}

# === UNIVERSAL — comando completo (patrones RCE y destruccion multi-linea) ===

# Pipe a bash (RCE classico)
if echo "$NO_QUOTES_FULL" | grep -qE 'curl.*\|.*(bash|sh|zsh)'; then
  deny "curl | bash bloqueado. Descarga el script, revisalo, y ejecutalo por separado."
fi
if echo "$NO_QUOTES_FULL" | grep -qE 'wget.*-O\s*-\s*.*\|.*(bash|sh|zsh)'; then
  deny "wget | bash bloqueado. Descarga el script, revisalo, y ejecutalo por separado."
fi

# DROP TABLE via echo/printf pipe (patron multi-comando)
if echo "$NO_QUOTES_FULL" | grep -qiE '(echo|printf|cat).*\bDROP\s+(TABLE|DATABASE|SCHEMA)\b.*\|'; then
  deny "DROP TABLE via pipe bloqueado. Ejecuta manualmente si es intencional."
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
  deny "Volcado del entorno bloqueado. 'env'/'printenv'/'export -p' imprimen TODAS las variables, incluidos los tokens que hoy tenes cargados. Si necesitas una variable puntual, nombrala; si necesitas saber si existe, usa: [ -n \"\${VAR:-}\" ] && echo definida."
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
  deny "Imprimir una variable con nombre de secreto bloqueado (*_KEY, *_SECRET, *_TOKEN, *_PASSWORD, *_CREDENTIAL). Va a stdout, al transcript y a los logs. Pasala directo al comando que la necesita — 'curl -H \"auth: \$TOKEN\"' esta permitido — o comproba solo si existe: [ -n \"\${VAR:-}\" ] && echo definida."
fi

if ! echo "$HAYSTACK" | grep -qE "$IS_TEMPLATE"; then
  if echo "$HAYSTACK" | grep -qE "\b(cat|bat|head|tail|less|more|nl|od|xxd|strings|base64|cp|mv|rsync|scp|open|source|\.)\b[^|;&]*${SECRET_ARG}"; then
    deny "Lectura de secretos por shell bloqueada (.env, credentials.json, claves privadas, certs). El deny de settings.json solo cubre el tool Read; esto cierra el mismo agujero por Bash. Si necesitas una variable, leela del entorno, no del archivo."
  fi
  if echo "$HAYSTACK" | grep -qE "\b(rg|grep|ag|ack|awk|sed|sd)\b[^|;&]*${SECRET_ARG}"; then
    deny "Grep/sed sobre un archivo de secretos bloqueado. Usa el nombre de la variable desde el entorno, no el contenido del archivo."
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
    deny "Operacion de esquema destructiva bloqueada. Estos comandos dropean o vacian tablas aunque el nombre no lo diga. Antes de correrlo a mano: (1) confirma a que base apunta la conexion, (2) verifica que exista un backup restaurable, (3) declara el blast radius al usuario. Ver rules/common/destructive-operations.md."
  fi

  # 2. Destino remoto explicito en cualquier operacion de esquema.
  if echo "$ORM_HAYSTACK" | grep -qEi "$REMOTE_DSN"; then
    if ! echo "$ORM_HAYSTACK" | grep -qEi "://[^[:space:]@]*(@)?${LOCAL_HOST}"; then
      deny "Operacion de esquema apuntando a un host REMOTO. Asi se vacio una base de produccion: el comando parecia inofensivo y la URL apuntaba a prod. Corre el esquema contra local, o pedile al usuario que lo ejecute el mismo contra ese host."
    fi
  fi

  # 3. Destino en una variable sin resolver: no se puede saber a donde apunta.
  # Este es EXACTAMENTE el caso del incidente ($DATABASE_URL_UNPOOLED).
  if echo "$ORM_HAYSTACK" | grep -qE '(--[a-z-]*(database-)?url[= ]|DATABASE_URL[A-Z_]*=)[^[:space:]]*\$'; then
    deny "El destino de esta operacion de esquema viene de una variable sin resolver, asi que ni vos ni el hook saben a que base apunta. Ese es el caso exacto que vacio una Supabase de produccion: --shadow-database-url recibia una variable que apuntaba a prod, y la shadow database se resetea por diseño. VERIFICA primero a donde resuelve (sin imprimir credenciales) y decilo antes de correr nada."
  fi
fi

# Destruccion de filesystem — sobre el comando COMPLETO: limitarlo a la primera
# linea dejaba pasar 'echo ok' seguido de 'rm -rf /'.
RM_RECURSIVE='\brm\s+(-[a-zA-Z]*\s+)*-?[a-zA-Z]*r[a-zA-Z]*f|\brm\s+(-[a-zA-Z]*\s+)*-?[a-zA-Z]*f[a-zA-Z]*r'
if echo "$NO_QUOTES_FULL" | grep -qE "$RM_RECURSIVE"; then
  # Solo el objetivo decide el nivel. Borrar la raiz o el home no se negocia;
  # borrar un build o un directorio temporal es trabajo normal.
  if echo "$NO_QUOTES_FULL" | grep -qE '\brm\s+(-[a-zA-Z]+\s+)+(/|/\*|~|~/|~/\*|\$HOME|\$HOME/|\$HOME/\*)(\s|$|;|&)'; then
    deny "rm -rf sobre la raiz o el home bloqueado. Es irreversible y no hay razon legitima para correrlo desde una sesion de agente."
  fi
  ask "rm -rf es irreversible. Revisa el path exacto antes de aprobar."
fi

if echo "$NO_QUOTES_FULL" | grep -qE '\bchmod\s+(-R\s+)?777\b'; then
  ask "chmod 777 deja el archivo escribible por cualquiera. Aprobalo solo si es un directorio descartable; si no, usa 644/755/700."
fi

# === BINARY-SPECIFIC ===
#
# Un comando trae varios binarios: 'cd repo && git push --force' arrancaba con
# 'cd', asi que el case de git no se evaluaba nunca. Se parte por los operadores
# de shell y se revisa CADA segmento.
# awk en vez de sed porque BSD sed (macOS) no interpreta \n en el reemplazo.
SEGMENTS=$(printf '%s' "$NO_QUOTES_FULL" | awk '{gsub(/&&|\|\||\||;/, "\n"); print}')

check_segment() {
  local segment="$1"
  local head binary
  head=$(printf '%s' "$segment" | awk '{print $1}')
  [ -z "$head" ] && return 0
  binary="${head##*/}"

  case "$binary" in
    sudo | doas)
      deny "sudo bloqueado. Ejecuta sin privilegios elevados."
      ;;
    git)
      # --force($|[^-]) = --force al final o seguido de espacio (no --force-with-lease)
      if echo "$segment" | grep -qE '\bpush\b.*--force($|[^-])'; then
        deny "git push --force bloqueado. Usa --force-with-lease si es necesario."
      fi
      if echo "$segment" | grep -qE '\bpush\b.*(\s-f\b|^-f\b)'; then
        deny "git push -f bloqueado. Usa --force-with-lease si es necesario."
      fi
      if echo "$segment" | grep -qE '\breset\s+.*--hard(\s|$)'; then
        deny "git reset --hard bloqueado. Usa git stash o git checkout -- <file> para descartes selectivos."
      fi
      # Descartan trabajo no commiteado, pero son parte del dia a dia: decide el usuario.
      if echo "$segment" | grep -qE '\bclean\b.*-[a-zA-Z]*[fdx]'; then
        ask "git clean borra archivos sin trackear de forma irreversible. Revisa 'git clean -n' antes de aprobar."
      fi
      if echo "$segment" | grep -qE '\bcheckout\b.*(\s-f\b|--force\b)'; then
        ask "git checkout -f descarta cambios locales sin backup. Aprobalo solo si sabes que no perdes nada."
      fi
      ;;
    npm)
      # -g standalone — evita falsos positivos con paquetes que terminan en -g
      if echo "$segment" | grep -qE '\b(install|i)\b.*(\s-g(\s|$)|^-g(\s|$))'; then
        deny "npm install -g bloqueado. Usa npx para herramientas one-shot."
      fi
      ;;
    pip | pip3)
      if echo "$segment" | grep -qE '\binstall\b.*--break-system-packages'; then
        deny "pip install --break-system-packages bloqueado. By-passea la proteccion del venv. Usa un venv o uv."
      fi
      ;;
    kubectl)
      if echo "$segment" | grep -qE '^\s*kubectl\s+delete\b'; then
        deny "kubectl delete bloqueado. Operacion destructiva en el cluster."
      fi
      ;;
    helm)
      if echo "$segment" | grep -qE '^\s*helm\s+(uninstall|delete)\b'; then
        deny "helm uninstall/delete bloqueado. Operacion destructiva en el cluster."
      fi
      ;;
    terraform)
      if echo "$segment" | grep -qE '\bterraform\s+destroy\b|\bterraform\s+apply\b.*-auto-approve'; then
        deny "terraform destroy/apply -auto-approve bloqueado. Infraestructura como codigo requiere revision manual."
      fi
      ;;
    mysql | psql | sqlite3 | mongo | mongosh | redis-cli | mariadb | cockroach | sqlplus | duckdb | clickhouse-client | bq | snowsql | mysqlsh)
      # Sobre el comando original (con quotes): el DROP suele ir dentro de -e "..." o -c "..."
      if echo "$COMMAND" | grep -qiE '\bDROP\s+(TABLE|DATABASE|SCHEMA)\b'; then
        deny "DROP TABLE/DATABASE bloqueado. Ejecuta manualmente si es intencional."
      fi
      ;;
    dd)
      if echo "$segment" | grep -qE '\bif='; then
        deny "dd bloqueado. Operacion de bajo nivel peligrosa."
      fi
      ;;
    mkfs | mkfs.* | newfs | newfs_msdos)
      deny "mkfs/newfs bloqueado. Formateo de filesystem es irreversible sin backup."
      ;;
  esac
}

while IFS= read -r segment; do
  check_segment "$segment"
done <<< "$SEGMENTS"

# Sin hallazgos: no opinamos. El flujo de permisos de settings.json decide.
exit 0

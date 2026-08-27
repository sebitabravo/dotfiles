#!/usr/bin/env bash
# privacy-review.sh — Pre-submission privacy scan for GitHub writes.
# Blocks private identifier categories without echoing the matched value back
# into Claude's transcript.
# Gentle-ai pattern: replace with explicit placeholders, never redact into nothingness.

set -euo pipefail

# Intercept common issue/PR publication commands and write-oriented gh api.
input="$(cat)"
cmd_str=""

# Extract command from JSON stdin
if command -v jq &>/dev/null; then
  if ! cmd_str="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)"; then
    echo "[Privacy Review] BLOCKED — could not parse the hook input; the content cannot be reviewed before publishing to GitHub." >&2
    exit 2
  fi
elif command -v python3 &>/dev/null; then
  if ! cmd_str="$(printf '%s' "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)"; then
    echo "[Privacy Review] BLOCKED — python3 could not parse the hook input; the content cannot be reviewed before publishing to GitHub." >&2
    exit 2
  fi
else
  echo "[Privacy Review] BLOCKED — jq/python3 is not available; the content cannot be reviewed before publishing to GitHub." >&2
  exit 2
fi

[[ -z "$cmd_str" ]] && exit 0

# Tokenize the command before classifying it.  Raw substring matching misses
# quoted options (`'--body-file'`) and global gh options (`gh --repo X pr ...`),
# while splitting on whitespace alone misreads quoted values.  shlex gives us a
# small, non-executing argv approximation; malformed shell syntax fails closed.
classification=""
if command -v python3 &>/dev/null; then
  if ! classification="$(
    PRIVACY_REVIEW_COMMAND="$cmd_str" python3 - <<'PY'
import os
import shlex

command = os.environ.get('PRIVACY_REVIEW_COMMAND', '')
try:
    lexer = shlex.shlex(command, posix=True, punctuation_chars=';&|')
    lexer.whitespace_split = True
    tokens = list(lexer)
except ValueError:
    print('AMBIGUOUS')
    raise SystemExit(0)

separators = {';', '&', '|', '&&', '||'}
segments = [[]]
for token in tokens:
    if token in separators:
        segments.append([])
    else:
        segments[-1].append(token)

target_verbs = {
    ('issue', 'create'), ('issue', 'comment'), ('issue', 'edit'), ('issue', 'review'),
    ('pr', 'create'), ('pr', 'comment'), ('pr', 'edit'), ('pr', 'review'),
    ('release', 'create'), ('gist', 'create'),
}

for segment in segments:
    if 'gh' not in segment:
        continue
    gh_index = segment.index('gh')
    args = segment[gh_index + 1:]
    command_kind = None
    for index in range(len(args) - 1):
        pair = (args[index], args[index + 1])
        if pair in target_verbs:
            command_kind = pair
            break
    if command_kind is None and 'api' in args:
        command_kind = ('api', 'write')
    if command_kind is None:
        continue

    if command_kind == ('gist', 'create'):
        print('OPAQUE gist')
        raise SystemExit(0)

    for index, token in enumerate(args):
        if token == '--body-file' or token.startswith('--body-file='):
            print('OPAQUE body-file')
            raise SystemExit(0)
        if command_kind == ('release', 'create') and (
            token == '--notes-file' or token.startswith('--notes-file=')
        ):
            print('OPAQUE notes-file')
            raise SystemExit(0)

        # -F has no uniform meaning across gh subcommands.  For publication
        # commands, treating it as opaque is safer than guessing whether the
        # argument is a body source.  gh api keeps validated inline key=value
        # fields, but rejects missing/ @file values as opaque.
        if token == '-F' or token == '--field' or token.startswith('-F') or token.startswith('--field='):
            if command_kind[0] in {'issue', 'pr', 'release'}:
                print('OPAQUE field')
                raise SystemExit(0)
            if token in {'-F', '--field'}:
                value = args[index + 1] if index + 1 < len(args) else ''
            elif token.startswith('--field='):
                value = token[len('--field='):]
            else:
                value = token[2:]
            if '=' not in value or value.split('=', 1)[1].startswith('@'):
                print('OPAQUE field')
                raise SystemExit(0)

        if command_kind == ('api', 'write') and (
            token == '--input' or token.startswith('--input=')
        ):
            print('OPAQUE input')
            raise SystemExit(0)

    print('TARGET')
    raise SystemExit(0)

print('NONE')
PY
  )"; then
    classification="AMBIGUOUS"
  fi
else
  # Python 3 is the normal parser on supported macOS installations.  Keep a
  # conservative fallback for minimal environments, normalizing quoted option
  # names first; anything it cannot classify is not treated as reviewed.
  normalized=${cmd_str//\'/}
  normalized=${normalized//\"/}
  if echo "$normalized" | grep -qE '(^|[;&|[:space:]])gh([[:space:]]+--repo([=[:space:]])[^[:space:]]+)?[[:space:]]+((issue|pr)[[:space:]]+(create|comment|edit|review)\b|release[[:space:]]+create\b|gist[[:space:]]+create\b|api\b)'; then
    classification="TARGET"
  else
    classification="NONE"
  fi
  # Preserve the fail-closed behavior when Python is unavailable.  The
  # fallback intentionally recognizes only the supported global --repo form;
  # anything more complex is left for the normal visible-payload scan rather
  # than guessed as a file-safe command.
  if [ "$classification" = TARGET ] &&
    echo "$normalized" | grep -qE '(^|[;&|[:space:]])gh([[:space:]]+--repo([=[:space:]])[^[:space:]]+)?[[:space:]]+((issue|pr)[[:space:]]+(create|comment|edit|review)\b|release[[:space:]]+create\b|gist[[:space:]]+create\b|api\b)[^;&|]*--body-file([=[:space:]]|$)'; then
    classification="OPAQUE body-file"
  elif [ "$classification" = TARGET ] &&
    echo "$normalized" | grep -qE '(^|[;&|[:space:]])gh([[:space:]]+--repo([=[:space:]])[^[:space:]]+)?[[:space:]]+(issue|pr)[[:space:]]+(create|comment|edit|review)\b[^;&|]*(-F|--field)([=[:space:]]|$)'; then
    classification="OPAQUE field"
  elif [ "$classification" = TARGET ] &&
    echo "$normalized" | grep -qE '(^|[;&|[:space:]])gh([[:space:]]+--repo([=[:space:]])[^[:space:]]+)?[[:space:]]+release[[:space:]]+create\b[^;&|]*(-F|--field)([=[:space:]]|$)'; then
    classification="OPAQUE field"
  elif [ "$classification" = TARGET ] &&
    echo "$normalized" | grep -qE '(^|[;&|[:space:]])gh([[:space:]]+--repo([=[:space:]])[^[:space:]]+)?[[:space:]]+release[[:space:]]+create\b[^;&|]*--notes-file([=[:space:]]|$)'; then
    classification="OPAQUE notes-file"
  elif [ "$classification" = TARGET ] &&
    echo "$normalized" | grep -qE '(^|[;&|[:space:]])gh([[:space:]]+--repo([=[:space:]])[^[:space:]]+)?[[:space:]]+gist[[:space:]]+create\b'; then
    classification="OPAQUE gist"
  elif [ "$classification" = TARGET ] &&
    echo "$normalized" | grep -qE '(^|[;&|[:space:]])gh([[:space:]]+--repo([=[:space:]])[^[:space:]]+)?[[:space:]]+api\b[^;&|]*--input([=[:space:]]|$)'; then
    classification="OPAQUE input"
  elif [ "$classification" = TARGET ] &&
    echo "$normalized" | grep -qE '(^|[;&|[:space:]])gh([[:space:]]+--repo([=[:space:]])[^[:space:]]+)?[[:space:]]+api\b[^;&|]*(-F|--field)([=[:space:]])[^[:space:]=]+=@'; then
    classification="OPAQUE field"
  fi
fi

case "$classification" in
  OPAQUE\ body-file)
    echo '[Privacy Review] BLOCKED — --body-file publishes file contents that this command-only review cannot verify. Review the file explicitly and use a redacted inline --body value or publish it manually.' >&2
    exit 2
    ;;
  OPAQUE\ notes-file)
    echo '[Privacy Review] BLOCKED — --notes-file publishes file contents that this command-only review cannot verify. Review the file explicitly and use a redacted inline --notes value or publish it manually.' >&2
    exit 2
    ;;
  OPAQUE\ gist)
    echo '[Privacy Review] BLOCKED — gh gist create publishes file or stdin contents that this command-only review cannot verify. Review the content explicitly and publish it manually.' >&2
    exit 2
    ;;
  OPAQUE\ field)
    echo '[Privacy Review] BLOCKED — this gh field form may publish file contents that this command-only review cannot verify. Review the source explicitly and use redacted inline fields or publish it manually.' >&2
    exit 2
    ;;
  OPAQUE\ input)
    echo '[Privacy Review] BLOCKED — gh api --input publishes file contents that this command-only review cannot verify. Review the file explicitly and use redacted inline fields or publish it manually.' >&2
    exit 2
    ;;
  AMBIGUOUS)
    if echo "$cmd_str" | grep -qE '(^|[;&|[:space:]])gh([[:space:]]|$)'; then
      echo '[Privacy Review] BLOCKED — could not safely tokenize a GitHub CLI command before publication.' >&2
      exit 2
    fi
    exit 0
    ;;
  NONE)
    exit 0
    ;;
esac

# Detect private identifiers
PRIVATE_PATTERNS=(
  "macOS home path|/Users/[a-zA-Z0-9]+"
  "Linux home path|/home/[a-zA-Z0-9]+"
  "local hostname|hostname:.*\.local"
  "GitHub classic token|ghp_[a-zA-Z0-9]{36,}"
  "GitHub fine-grained token|github_pat_[a-zA-Z0-9_]{22,}"
  "OpenAI-style token|sk-[a-zA-Z0-9]{32,}"
  "AWS access key|AKIA[0-9A-Z]{16}"
  "Slack token|xox[bprs]-[0-9A-Za-z-]+"
)

violations=""
for entry in "${PRIVATE_PATTERNS[@]}"; do
  label=${entry%%|*}
  pattern=${entry#*|}
  # Use ggrep (GNU grep) if available, fall back to grep -E with basic patterns
  # El '--' separa flags del patron: sin el, un patron que empieza con '-' se
  # parsea como opciones y el match falla en silencio.
  if command -v ggrep &>/dev/null; then
    match="$(echo "$cmd_str" | ggrep -oP -- "$pattern" 2>/dev/null | head -5 || true)"
  elif command -v rg &>/dev/null; then
    # ripgrep supports PCRE2 with --pcre2 flag
    match="$(echo "$cmd_str" | rg -oP -- "$pattern" 2>/dev/null | head -5 || true)"
  else
    # Last resort: grep -E (limited, won't match all patterns)
    match="$(echo "$cmd_str" | grep -oE -- "$pattern" 2>/dev/null | head -5 || true)"
  fi
  if [[ -n "$match" ]]; then
    violations+="  - ${label}"$'\n'
  fi
done

# Emails reales, aparte del loop de arriba porque necesitan exclusion de
# dominios (RFC 2606 + noreply de GitHub, que son justo los placeholders que
# este mismo hook recomienda usar). La version anterior metia la exclusion
# como negative lookahead '(?!...)' dentro del patron: ggrep/rg lo soportan
# via PCRE, pero el ultimo recurso (grep -E, ERE puro) no — el patron entero
# fallaba en silencio ahi, y el detector de emails quedaba mudo en cualquier
# maquina sin ggrep ni rg instalados.
# Match simple + filtro por separado funciona igual en los tres grep, porque
# ninguno de los dos pasos necesita lookahead.
EMAIL_PATTERN="[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"
EMAIL_EXCLUDE='@(example\.(com|org|net)|test|invalid|localhost|users\.noreply\.github\.com)($|[^A-Za-z0-9_])'
email_match="$(echo "$cmd_str" | grep -oE -- "$EMAIL_PATTERN" 2>/dev/null | grep -vE -- "$EMAIL_EXCLUDE" | head -5 || true)"
if [[ -n "$email_match" ]]; then
  violations+="  - email address"$'\n'
fi

if [[ -n "$violations" ]]; then
  {
    echo "[Privacy Review] BLOCKED — private identifier categories detected in GitHub publication:"
    echo "$violations"
    echo ""
    echo "Replace private identifiers with explicit placeholders BEFORE publishing:"
    echo "  /Users/<username>  →  <project-path>"
    echo "  user@example.com   →  <email>"
    echo "  ghp_*              →  <token>"
    echo "  hostname.local     →  <hostname>"
    echo ""
    echo "Never redact into nothingness — preserve reproduction structure with placeholders."
    echo "Fix the body and retry."
  } >&2
  exit 2
fi

exit 0

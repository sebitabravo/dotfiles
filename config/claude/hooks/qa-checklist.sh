#!/bin/bash
# qa-checklist.sh — Stop hook
# Checks that modified code has corresponding tests before declaring done.
# Does not block (exit 0), only reports to stderr as a QA reminder.

INPUT=$(cat 2>/dev/null || printf '%s' '{}')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
PROJECT_DIR="${CWD:-$PWD}"
ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PROJECT_DIR")
cd "$ROOT" 2>/dev/null || exit 0

WARNINGS=""

# 1. Check for modified source files without corresponding tests
# Only for files in src/ or app/ (production code).
# El filtro de extension va FUERA del subshell: adentro solo aplicaba al ultimo
# comando (git ls-files), asi que los archivos de git diff entraban sin filtrar
# y despues se escaneaban .md y .json buscando console.log/print(.
CHANGED_FILES=$(
  {
    git diff --name-only HEAD 2>/dev/null
    git diff --name-only --cached 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | grep -E '\.(ts|tsx|js|jsx|py|go|rs|rb|php|java)$' | sort -u
)

if [ -n "$CHANGED_FILES" ]; then
  SRC_FILES=$(echo "$CHANGED_FILES" | grep -E '^src/|^app/|^lib/|^internal/' | grep -vE 'test|spec|__test__|\.test\.|\.spec\.' || true)
  if [ -n "$SRC_FILES" ]; then
    MISSING_TESTS=""
    while IFS= read -r src; do
      [ -n "$src" ] || continue
      # Find corresponding test file
      base=$(basename "$src")
      dir=$(dirname "$src")
      stem="${base%.*}"
      # Common patterns: foo.test.ts, foo.spec.ts, test_foo.py, foo_test.py, foo_test.go
      has_test=false
      for pattern in "${stem}.test" "${stem}.spec" "test_${stem}" "${stem}_test"; do
        if find "$dir" -maxdepth 1 -name "${pattern}.*" 2>/dev/null | grep -q .; then
          has_test=true
          break
        fi
      done
      # Also check adjacent __tests__/ or tests/ directory
      if [ "$has_test" = false ]; then
        testdir=$(dirname "$dir")/tests
        for pattern in "${stem}.test" "${stem}.spec" "test_${stem}" "${stem}_test"; do
          if find "$testdir" -maxdepth 1 -name "${pattern}.*" 2>/dev/null | grep -q .; then
            has_test=true
            break
          fi
        done
      fi
      if [ "$has_test" = false ]; then
        MISSING_TESTS="${MISSING_TESTS}\n  - $src"
      fi
    done <<< "$SRC_FILES"
    if [ -n "$MISSING_TESTS" ]; then
      WARNINGS="${WARNINGS}\n[qa-checklist] Files without corresponding test:${MISSING_TESTS}"
    fi
  fi
fi

# 2. Check for debug statements in modified files
DEBUG_FOUND=""
while IFS= read -r file; do
  [ -n "$file" ] || continue
  if [ -f "$file" ]; then
    # Hook infrastructure prints JSON on stdout/stderr by contract. It is not
    # a production debug statement, so never report it as console.log/print.
    case "$file" in
      */hooks/*) continue ;;
    esac
    # `print()` es salida normal en Python CLIs y scripts, no prueba de debug.
    # Detectamos primitivas explícitas de debugger para no reportar falsos
    # positivos como el de scripts/validate-task-roadmap.py.
    if grep -nE '(console\.(log|warn|error|debug)|breakpoint\(|pdb\.set_trace|debugger|binding\.pry|byebug|var_dump|dd\()' "$file" 2>/dev/null | grep -qE '^\s*[0-9]+:\s*(console|breakpoint|pdb|debugger|binding|byebug|var_dump|dd)'; then
      DEBUG_FOUND="${DEBUG_FOUND}\n  - $file"
    fi
  fi
done <<< "$CHANGED_FILES"
if [ -n "$DEBUG_FOUND" ]; then
  WARNINGS="${WARNINGS}\n[qa-checklist] Debug statements detected:${DEBUG_FOUND}"
fi

# 3. Check for unresolved TODO/FIXME in modified files
# Solo archivos de codigo: en .md y en los propios hooks la palabra "TODO"
# aparece como texto legitimo (este script se auto-reportaba por su propia regex).
TODO_FOUND=""
while IFS= read -r file; do
  [ -n "$file" ] || continue
  [ -f "$file" ] || continue
  case "$file" in
    *.md | *.txt | *.rst | *.adoc) continue ;;
    */hooks/*.sh | */hooks/*.py) continue ;;
    *.json | *.yml | *.yaml | *.toml) continue ;;
  esac
  # Requiere marcador de comentario antes del tag, asi "dangling TODOs" en prosa no cuenta.
  if grep -qE '(//|#|/\*|\*|<!--)[[:space:]]*(TODO|FIXME|HACK|XXX)\b' "$file" 2>/dev/null; then
    TODO_FOUND="${TODO_FOUND}\n  - $file"
  fi
done <<< "$CHANGED_FILES"
if [ -n "$TODO_FOUND" ]; then
  WARNINGS="${WARNINGS}\n[qa-checklist] Unresolved TODO/FIXME:${TODO_FOUND}"
fi

# 4. Human merge gate checklist
#
# Solo se imprime si los checks de arriba encontraron algo. Este hook corre en
# Stop, que dispara UNA VEZ POR TURNO — imprimirlo siempre metia ~290 tokens de
# checklist en cada respuesta, y un recordatorio que aparece siempre se vuelve
# invisible. Si no hay hallazgos, el hook calla.
if [ -z "$WARNINGS" ]; then
  exit 0
fi

WARNINGS="${WARNINGS}\n[qa-checklist] === HUMAN MERGE GATE ==="
WARNINGS="${WARNINGS}\n  Before declaring done, verify ALL of the following:"
WARNINGS="${WARNINGS}\n"
WARNINGS="${WARNINGS}\n  CODE QUALITY"
WARNINGS="${WARNINGS}\n  [ ] Lint passes with zero warnings"
WARNINGS="${WARNINGS}\n  [ ] Tests pass (unit + integration)"
WARNINGS="${WARNINGS}\n  [ ] Coverage >= 80% line, >= 70% branch (quality-metrics skill)"
WARNINGS="${WARNINGS}\n  [ ] No debug statements (console.log, print, var_dump, dd, debugger)"
WARNINGS="${WARNINGS}\n  [ ] No unresolved TODO/FIXME/HACK/XXX"
WARNINGS="${WARNINGS}\n"
WARNINGS="${WARNINGS}\n  SCOPE & REVIEW"
WARNINGS="${WARNINGS}\n  [ ] Diff contains ONLY the intended change (no scope creep)"
WARNINGS="${WARNINGS}\n  [ ] Independent review completed (code-reviewer + security-auditor, NOT self-reviewed)"
WARNINGS="${WARNINGS}\n  [ ] All actionable review threads resolved"
WARNINGS="${WARNINGS}\n"
WARNINGS="${WARNINGS}\n  SPEC & DOCS"
WARNINGS="${WARNINGS}\n  [ ] BDD: complex features have .feature files (bdd-gherkin skill)"
WARNINGS="${WARNINGS}\n  [ ] Documentation matches the implemented behavior"
WARNINGS="${WARNINGS}\n  [ ] Changelog updated if user-facing change"
WARNINGS="${WARNINGS}\n"
WARNINGS="${WARNINGS}\n  REAL-WORLD VERIFICATION"
WARNINGS="${WARNINGS}\n  [ ] Feature tested in target environment (not just unit tests)"
WARNINGS="${WARNINGS}\n  [ ] Visible changes confirmed on screen (screenshot or live check)"
WARNINGS="${WARNINGS}\n  [ ] Mutation testing in CI for critical features >= 80% (mutation-testing skill)"

# Show warnings on stderr (visible to agent, does not block)
if [ -n "$WARNINGS" ]; then
  echo -e "$WARNINGS" >&2
fi

exit 0

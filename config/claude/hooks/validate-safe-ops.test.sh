#!/usr/bin/env bash
# Fixtures de la regla RM_TEST: borrar cobertura por Bash debe pedir
# confirmacion, y el trabajo normal no debe sufrir friccion.
cd "$(dirname "$0")" || exit 1
FAILED=0
probe() {
  out=$(echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}" | bash validate-safe-ops.sh 2>&1)
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)
  [ -z "$dec" ] && dec="(allow)"
  if [ "$dec" = "$2" ]; then
    printf 'PASS  %-40s %s\n' "$1" "$dec"
  else
    printf 'FAIL  %-40s %-8s esperaba %s\n' "$1" "$dec" "$2"; FAILED=1
  fi
}
probe 'rm tests/foo.test.ts'           ask
probe 'rm test_login.py'               ask
probe 'rm tests/helpers.py'            ask
probe 'rm UserTest.java'               ask
probe 'rm src/__snapshots__/a.snap'    ask
probe 'rm -f spec/models/user_spec.rb' ask
probe 'rm features/login.feature'      ask
probe 'cd app && rm test_api.py'       ask
probe 'rm dist/bundle.js'    '(allow)'
probe 'rm README.md'         '(allow)'
probe 'rm latest.js'         '(allow)'
probe 'rm src/contests.py'   '(allow)'
probe 'npm run build'        '(allow)'
probe 'git status'           '(allow)'
probe 'echo confirm'         '(allow)'
echo "---"; [ "$FAILED" = 0 ] && echo "TODO VERDE" || echo "HAY FALLAS"
exit "$FAILED"

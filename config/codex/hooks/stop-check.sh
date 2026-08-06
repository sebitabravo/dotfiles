#!/usr/bin/env bash
# Stop: run the strict, bounded QA gate. The implementation lives in Python so
# project test commands are executed as argv, never through eval or shell=True.
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/qa-gate.py"

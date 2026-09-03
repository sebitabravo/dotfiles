#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
cd "$REPO_ROOT"

PYTHONDONTWRITEBYTECODE=1 python3 -B \
  .github/test/stitch-upload-security.test.py
PYTHONDONTWRITEBYTECODE=1 python3 -B \
  .github/test/office-archive-safety.test.py

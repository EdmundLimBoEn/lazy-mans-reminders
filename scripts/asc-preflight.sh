#!/usr/bin/env bash
# Read-only GET requests only; never submits or changes App Store Connect.
set -euo pipefail
if ! command -v python3 >/dev/null 2>&1; then
  echo 'FAIL python3 is required.' >&2
  exit 1
fi
exec python3 "$(dirname "${BASH_SOURCE[0]}")/asc-preflight.py" "$@"

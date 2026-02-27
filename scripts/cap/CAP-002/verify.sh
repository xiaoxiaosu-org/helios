#!/usr/bin/env bash
set -euo pipefail

if [ ! -x scripts/e2e/run-ui-check.sh ]; then
  echo "[CAP-002] missing executable: scripts/e2e/run-ui-check.sh" >&2
  exit 2
fi

scripts/e2e/run-ui-check.sh --headless --out "${ARTIFACT_DIR}"

test -d "${ARTIFACT_DIR}/screenshots" || exit 1
if ! find "${ARTIFACT_DIR}/screenshots" -type f | head -n 1 | grep -q .; then
  exit 1
fi


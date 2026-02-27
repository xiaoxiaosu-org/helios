#!/usr/bin/env bash
set -euo pipefail

if [ ! -x scripts/ci/logging-check.sh ]; then
  echo "[CAP-005] missing executable: scripts/ci/logging-check.sh" >&2
  exit 2
fi

scripts/ci/logging-check.sh --out "${ARTIFACT_DIR}"
test -f "${ARTIFACT_DIR}/logging-check-report.json" || test -f "${ARTIFACT_DIR}/logging-check-report.txt" || exit 1


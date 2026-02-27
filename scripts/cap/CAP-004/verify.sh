#!/usr/bin/env bash
set -euo pipefail

if [ ! -x scripts/ci/arch-check.sh ]; then
  echo "[CAP-004] missing executable: scripts/ci/arch-check.sh" >&2
  exit 2
fi

scripts/ci/arch-check.sh --out "${ARTIFACT_DIR}"
test -f "${ARTIFACT_DIR}/arch-check-report.json" || test -f "${ARTIFACT_DIR}/arch-check-report.txt" || exit 1


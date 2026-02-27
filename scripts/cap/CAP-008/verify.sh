#!/usr/bin/env bash
set -euo pipefail

missing=0
if [ ! -x scripts/docs/gardening.sh ]; then
  echo "[CAP-008] missing executable: scripts/docs/gardening.sh" >&2
  missing=1
fi
if [ ! -f .github/workflows/doc-gardening.yml ]; then
  echo "[CAP-008] missing workflow: .github/workflows/doc-gardening.yml" >&2
  missing=1
fi

if [ "$missing" -eq 1 ]; then
  exit 2
fi

scripts/docs/gardening.sh --out "${ARTIFACT_DIR}"
test -f "${ARTIFACT_DIR}/report.md" || exit 1


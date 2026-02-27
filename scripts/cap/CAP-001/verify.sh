#!/usr/bin/env bash
set -euo pipefail

missing=0

for f in scripts/dev/sandbox-create.sh scripts/dev/sandbox-destroy.sh; do
  if [ ! -x "$f" ]; then
    echo "[CAP-001] missing executable: $f" >&2
    missing=1
  fi
done

if [ "$missing" -eq 1 ]; then
  exit 2
fi

scripts/dev/sandbox-create.sh --smoke --out "${ARTIFACT_DIR}"
scripts/dev/sandbox-destroy.sh --smoke --out "${ARTIFACT_DIR}"

test -f "${ARTIFACT_DIR}/sandbox.env" || exit 1
test -f "${ARTIFACT_DIR}/cleanup.log" || exit 1


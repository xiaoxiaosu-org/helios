#!/usr/bin/env bash
set -euo pipefail

if [ ! -x scripts/obs/smoke-trace.sh ] || [ ! -x scripts/obs/query-trace.sh ]; then
  echo "[CAP-003] missing executables: scripts/obs/smoke-trace.sh and/or scripts/obs/query-trace.sh" >&2
  exit 2
fi

scripts/obs/smoke-trace.sh --out "${ARTIFACT_DIR}"
test -f "${ARTIFACT_DIR}/traceId.txt" || exit 1

trace_id="$(cat "${ARTIFACT_DIR}/traceId.txt" | tr -d '\n' || true)"
test -n "${trace_id}" || exit 1

scripts/obs/query-trace.sh "${trace_id}" --out "${ARTIFACT_DIR}"
test -f "${ARTIFACT_DIR}/trace.json" || test -f "${ARTIFACT_DIR}/trace.txt" || exit 1


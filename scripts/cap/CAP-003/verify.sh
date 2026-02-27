#!/usr/bin/env bash
set -euo pipefail

start_s="$(date +%s)"
trap 'rc=$?; end_s=$(date +%s); dur=$(( end_s - start_s )); if [ "$rc" -eq 0 ]; then echo "[CAP-003] 结束：成功（耗时 ${dur}s）"; else echo "[CAP-003] 结束：失败/阻塞（退出码 ${rc}，耗时 ${dur}s）"; fi' EXIT
echo "[CAP-003] 启动：可观测闭环验收"

if [ ! -x scripts/obs/smoke-trace.sh ] || [ ! -x scripts/obs/query-trace.sh ]; then
  echo "[CAP-003] 缺少或不可执行：scripts/obs/smoke-trace.sh 或 scripts/obs/query-trace.sh" >&2
  exit 2
fi

scripts/obs/smoke-trace.sh --out "${ARTIFACT_DIR}"
test -f "${ARTIFACT_DIR}/traceId.txt" || exit 1

trace_id="$(cat "${ARTIFACT_DIR}/traceId.txt" | tr -d '\n' || true)"
test -n "${trace_id}" || exit 1

scripts/obs/query-trace.sh "${trace_id}" --out "${ARTIFACT_DIR}"
test -f "${ARTIFACT_DIR}/trace.json" || test -f "${ARTIFACT_DIR}/trace.txt" || exit 1

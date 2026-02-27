#!/usr/bin/env bash
set -euo pipefail

start_s="$(date +%s)"
trap 'rc=$?; end_s=$(date +%s); dur=$(( end_s - start_s )); if [ "$rc" -eq 0 ]; then echo "[CAP-004] 结束：成功（耗时 ${dur}s）"; else echo "[CAP-004] 结束：失败/阻塞（退出码 ${rc}，耗时 ${dur}s）"; fi' EXIT
echo "[CAP-004] 启动：架构边界门禁验收"

if [ ! -x scripts/ci/arch-check.sh ]; then
  echo "[CAP-004] 缺少或不可执行：scripts/ci/arch-check.sh" >&2
  exit 2
fi

scripts/ci/arch-check.sh --out "${ARTIFACT_DIR}"
test -f "${ARTIFACT_DIR}/arch-check-report.json" || test -f "${ARTIFACT_DIR}/arch-check-report.txt" || exit 1

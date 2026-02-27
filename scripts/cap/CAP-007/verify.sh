#!/usr/bin/env bash
set -euo pipefail

start_s="$(date +%s)"
trap 'rc=$?; end_s=$(date +%s); dur=$(( end_s - start_s )); if [ "$rc" -eq 0 ]; then echo "[CAP-007] 结束：成功（耗时 ${dur}s）"; else echo "[CAP-007] 结束：失败/阻塞（退出码 ${rc}，耗时 ${dur}s）"; fi' EXIT
echo "[CAP-007] 启动：技术债清单验收"

f="docs/02-架构/技术债清单.md"
test -f "${f}" || exit 1

if ! rg -n "TD-[0-9]{3}" "${f}" >/dev/null; then
  exit 1
fi

{
  echo "通过：${f}"
} > "${ARTIFACT_DIR}/tech-debt-check.txt"

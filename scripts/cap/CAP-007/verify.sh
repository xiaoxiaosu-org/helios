#!/usr/bin/env bash
set -euo pipefail

start_s="$(date +%s)"
trap 'rc=$?; end_s=$(date +%s); dur=$(( end_s - start_s )); if [ "$rc" -eq 0 ]; then echo "[CAP-007] 结束：成功（耗时 ${dur}s）"; else echo "[CAP-007] 结束：失败/阻塞（退出码 ${rc}，耗时 ${dur}s）"; fi' EXIT
echo "[CAP-007] 启动：技术债清单验收"

f="docs/02-架构/技术债清单.md"
if [ ! -f "${f}" ]; then
  echo "[CAP-007] 缺少文件：${f}" >&2
  exit 1
fi

if ! rg -n "TD-[0-9]{3}" "${f}" >/dev/null; then
  echo "[CAP-007] 未检测到技术债 ID（TD-XXX）" >&2
  exit 1
fi

if ! rg -n "Owner|最近更新|验收标准" "${f}" >/dev/null; then
  echo "[CAP-007] 清单缺少关键字段（Owner/最近更新/验收标准）" >&2
  exit 1
fi

if ! rg -n "\\| (Open|In Progress|Blocked|Done) \\|" "${f}" >/dev/null; then
  echo "[CAP-007] 清单中未检测到合法状态值（Open/In Progress/Blocked/Done）" >&2
  exit 1
fi

{
  echo "通过：${f}"
  echo "检查项：存在 TD 记录、关键字段、合法状态"
} > "${ARTIFACT_DIR}/tech-debt-check.txt"

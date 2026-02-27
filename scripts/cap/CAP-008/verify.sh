#!/usr/bin/env bash
set -euo pipefail

start_s="$(date +%s)"
trap 'rc=$?; end_s=$(date +%s); dur=$(( end_s - start_s )); if [ "$rc" -eq 0 ]; then echo "[CAP-008] 结束：成功（耗时 ${dur}s）"; else echo "[CAP-008] 结束：失败/阻塞（退出码 ${rc}，耗时 ${dur}s）"; fi' EXIT
echo "[CAP-008] 启动：doc-gardening 验收"

missing=0
if [ ! -x scripts/docs/gardening.sh ]; then
  echo "[CAP-008] 缺少或不可执行：scripts/docs/gardening.sh" >&2
  missing=1
fi
if [ ! -f .github/workflows/doc-gardening.yml ]; then
  echo "[CAP-008] 缺少 workflow：.github/workflows/doc-gardening.yml" >&2
  missing=1
fi

if [ "$missing" -eq 1 ]; then
  exit 2
fi

scripts/docs/gardening.sh --out "${ARTIFACT_DIR}"
test -f "${ARTIFACT_DIR}/report.md" || exit 1

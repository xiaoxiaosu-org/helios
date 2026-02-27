#!/usr/bin/env bash
set -euo pipefail

start_s="$(date +%s)"
trap 'rc=$?; end_s=$(date +%s); dur=$(( end_s - start_s )); if [ "$rc" -eq 0 ]; then echo "[CAP-002] 结束：成功（耗时 ${dur}s）"; else echo "[CAP-002] 结束：失败/阻塞（退出码 ${rc}，耗时 ${dur}s）"; fi' EXIT
echo "[CAP-002] 启动：UI 自动化验收"

if [ ! -x scripts/e2e/run-ui-check.sh ]; then
  echo "[CAP-002] 缺少或不可执行：scripts/e2e/run-ui-check.sh" >&2
  exit 2
fi

scripts/e2e/run-ui-check.sh --headless --out "${ARTIFACT_DIR}"

test -d "${ARTIFACT_DIR}/screenshots" || exit 1
if ! find "${ARTIFACT_DIR}/screenshots" -type f | head -n 1 | grep -q .; then
  exit 1
fi

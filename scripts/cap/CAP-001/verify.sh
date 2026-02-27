#!/usr/bin/env bash
set -euo pipefail

start_s="$(date +%s)"
trap 'rc=$?; end_s=$(date +%s); dur=$(( end_s - start_s )); if [ "$rc" -eq 0 ]; then echo "[CAP-001] 结束：成功（耗时 ${dur}s）"; else echo "[CAP-001] 结束：失败/阻塞（退出码 ${rc}，耗时 ${dur}s）"; fi' EXIT
echo "[CAP-001] 启动：任务沙盒验收"

missing=0

for f in scripts/dev/sandbox-create.sh scripts/dev/sandbox-destroy.sh; do
  if [ ! -x "$f" ]; then
    echo "[CAP-001] 缺少或不可执行：$f" >&2
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

#!/usr/bin/env bash
set -euo pipefail

start_s="$(date +%s)"
trap 'rc=$?; end_s=$(date +%s); dur=$(( end_s - start_s )); if [ "$rc" -eq 0 ]; then echo "[CAP-009] 结束：成功（耗时 ${dur}s）"; else echo "[CAP-009] 结束：失败/阻塞（退出码 ${rc}，耗时 ${dur}s）"; fi' EXIT
echo "[CAP-009] 启动：PR 闭环资产验收"

tmpl=""
if [ -f .github/pull_request_template.md ]; then
  tmpl=".github/pull_request_template.md"
elif [ -f .github/PULL_REQUEST_TEMPLATE.md ]; then
  tmpl=".github/PULL_REQUEST_TEMPLATE.md"
fi

if [ -z "${tmpl}" ]; then
  echo "[CAP-009] 缺少 PR 模板（.github/pull_request_template.md 或 .github/PULL_REQUEST_TEMPLATE.md）" >&2
  exit 2
fi

grep -q "\\[ \\]" "${tmpl}" || exit 1
grep -q "docs" "${tmpl}" || exit 1
grep -q "ADR" "${tmpl}" || exit 1

{
  echo "通过：${tmpl}"
} > "${ARTIFACT_DIR}/pr-template-check.txt"

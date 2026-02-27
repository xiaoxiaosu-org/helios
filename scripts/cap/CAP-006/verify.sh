#!/usr/bin/env bash
set -euo pipefail

start_s="$(date +%s)"
trap 'rc=$?; end_s=$(date +%s); dur=$(( end_s - start_s )); if [ "$rc" -eq 0 ]; then echo "[CAP-006] 结束：成功（耗时 ${dur}s）"; else echo "[CAP-006] 结束：失败/阻塞（退出码 ${rc}，耗时 ${dur}s）"; fi' EXIT
echo "[CAP-006] 启动：质量评分文档验收"

f="docs/02-架构/质量评分与演进.md"
test -f "${f}" || exit 1

grep -q "## 评分维度" "${f}" || exit 1
grep -q "## 当前现状" "${f}" || exit 1
grep -q "## 下一步" "${f}" || exit 1

{
  echo "通过：${f}"
} > "${ARTIFACT_DIR}/quality-score-check.txt"

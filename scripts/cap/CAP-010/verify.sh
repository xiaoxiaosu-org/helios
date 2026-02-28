#!/usr/bin/env bash
set -euo pipefail

start_s="$(date +%s)"
trap 'rc=$?; end_s=$(date +%s); dur=$(( end_s - start_s )); if [ "$rc" -eq 0 ]; then echo "[CAP-010] 结束：成功（耗时 ${dur}s）"; else echo "[CAP-010] 结束：失败/阻塞（退出码 ${rc}，耗时 ${dur}s）"; fi' EXIT

echo "[CAP-010] 启动：PR 校验鲁棒性验收"

if [ ! -x scripts/ci/gate-selftest.sh ]; then
  echo "[CAP-010] 缺少或不可执行：scripts/ci/gate-selftest.sh" >&2
  exit 2
fi

if [ ! -f .github/workflows/quality-gates.yml ] || [ ! -f .github/workflows/doc-check.yml ]; then
  echo "[CAP-010] 缺少 workflow：quality-gates.yml 或 doc-check.yml" >&2
  exit 2
fi

scripts/ci/gate-selftest.sh "${ARTIFACT_DIR}/gate-selftest"

grep -F "Run gate self-tests (CAP-010)" .github/workflows/quality-gates.yml >/dev/null || {
  echo "[CAP-010] quality-gates.yml 缺少 CAP-010 gate-selftest 步骤" >&2
  exit 1
}

grep -F "before SHA 不可达" .github/workflows/quality-gates.yml >/dev/null || {
  echo "[CAP-010] quality-gates.yml 缺少 before SHA 不可达回退逻辑" >&2
  exit 1
}

grep -F "before SHA 不可达" .github/workflows/doc-check.yml >/dev/null || {
  echo "[CAP-010] doc-check.yml 缺少 before SHA 不可达回退逻辑" >&2
  exit 1
}

if [ ! -f "${ARTIFACT_DIR}/gate-selftest/gate-selftest-report.txt" ]; then
  echo "[CAP-010] 缺少门禁自测报告：${ARTIFACT_DIR}/gate-selftest/gate-selftest-report.txt" >&2
  exit 1
fi

echo "[CAP-010] 通过：门禁自测与 push diff 回退逻辑校验通过"

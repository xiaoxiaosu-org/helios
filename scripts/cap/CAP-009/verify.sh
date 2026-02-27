#!/usr/bin/env bash
set -euo pipefail

start_s="$(date +%s)"
trap 'rc=$?; end_s=$(date +%s); dur=$(( end_s - start_s )); if [ "$rc" -eq 0 ]; then echo "[CAP-009] 结束：成功（耗时 ${dur}s）"; else echo "[CAP-009] 结束：失败/阻塞（退出码 ${rc}，耗时 ${dur}s）"; fi' EXIT
echo "[CAP-009] 启动：PR 闭环资产验收"

pr_report="${ARTIFACT_DIR}/pr-template-check.txt"
: > "${pr_report}"

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

required_checks=(
  "docs::^[[:space:]]*-[[:space:]]*\\[[ xX]\\].*(docs/|docs)"
  "ADR::^[[:space:]]*-[[:space:]]*\\[[ xX]\\].*ADR"
  "测试::^[[:space:]]*-[[:space:]]*\\[[ xX]\\].*(scripts/ci/verify\\.sh|验证|Verification|测试)"
  "trace::^[[:space:]]*-[[:space:]]*\\[[ xX]\\].*(traceId|Trace|可观测性)"
  "安全::^[[:space:]]*-[[:space:]]*\\[[ xX]\\].*(安全|Security|密钥|鉴权|审计)"
)

fail_count=0
for item in "${required_checks[@]}"; do
  name="${item%%::*}"
  pattern="${item#*::}"
  if grep -Eq "${pattern}" "${tmpl}"; then
    echo "通过：PR 模板包含 ${name} 勾选项" >> "${pr_report}"
  else
    echo "失败：PR 模板缺少 ${name} 勾选项（${tmpl}）" | tee -a "${pr_report}" >&2
    fail_count=$((fail_count + 1))
  fi
done

ci_report="${ARTIFACT_DIR}/ci-guidance-check.txt"
: > "${ci_report}"
guidance_patterns=(
  ".github/workflows/doc-check.yml::下一步：补充 .github/pull_request_template.md 或 .github/PULL_REQUEST_TEMPLATE.md"
  ".github/workflows/doc-check.yml::下一步：按 .github/pull_request_template.md 完整填写 PR 描述后重试。"
  ".github/workflows/doc-check.yml::下一步：补齐缺失段落后重试；模板见 .github/pull_request_template.md。"
  ".github/workflows/doc-check.yml::下一步：至少勾选 1 个变更类型复选框"
  ".github/workflows/doc-check.yml::下一步：同步更新 docs/02-架构/工程治理/Git门禁与模板对照清单.md"
  ".github/workflows/quality-gates.yml::下一步：新增 .github/CODEOWNERS（或仓库根 CODEOWNERS）并提交。"
  ".github/workflows/quality-gates.yml::下一步：补齐并赋予可执行权限"
)

for item in "${guidance_patterns[@]}"; do
  file="${item%%::*}"
  pattern="${item#*::}"
  if grep -F "${pattern}" "${file}" >/dev/null; then
    echo "通过：${file} 包含指路信息 -> ${pattern}" >> "${ci_report}"
  else
    echo "失败：${file} 缺少指路信息 -> ${pattern}" | tee -a "${ci_report}" >&2
    fail_count=$((fail_count + 1))
  fi
done

if [ "${fail_count}" -ne 0 ]; then
  exit 1
fi

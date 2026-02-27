#!/usr/bin/env bash
set -euo pipefail

now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log() {
  echo "[git-governance][$(now)] $*"
}

fail() {
  echo "[git-governance][$(now)] $*" >&2
  exit 1
}

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${root}"

require_file() {
  local file="$1"
  [ -f "${file}" ] || fail "缺少必需文件：${file}"
}

require_exec() {
  local file="$1"
  [ -x "${file}" ] || fail "文件必须可执行：${file}"
}

require_in_file() {
  local needle="$1"
  local file="$2"
  grep -F "${needle}" "${file}" >/dev/null || fail "文档缺少描述：${needle}（文件：${file}）"
}

forbid_in_file() {
  local needle="$1"
  local file="$2"
  if grep -F "${needle}" "${file}" >/dev/null; then
    fail "检测到重复细项，请保留在唯一信息源文档中：${needle}（文件：${file}）"
  fi
}

extract_commit_headers_from_hook() {
  awk '
    /required_headers=\(/ {in_arr=1; next}
    in_arr && /\)/ {in_arr=0; exit}
    in_arr {print}
  ' .githooks/commit-msg | sed -n 's/^[[:space:]]*"\(.*:\)".*$/\1/p'
}

extract_commit_headers_from_template() {
  grep -E '^[^[:space:]-].*:$' .github/commit_message_template.md | sed 's/[[:space:]]*$//'
}

extract_pr_sections_from_workflow() {
  awk '
    /required_sections=\(/ {in_arr=1; next}
    in_arr && /\)/ {in_arr=0; exit}
    in_arr {print}
  ' .github/workflows/doc-check.yml | sed -n 's/^[[:space:]]*"\(## [^"]*\)".*$/\1/p'
}

extract_pr_sections_from_template() {
  grep -E '^## ' .github/pull_request_template.md | sed 's/[[:space:]]*$//'
}

log "启动：Git 门禁/Hook/模板一致性校验"

required_files=(
  ".githooks/pre-commit"
  ".githooks/commit-msg"
  ".githooks/pre-push"
  ".github/commit_message_template.md"
  ".github/pull_request_template.md"
  ".github/workflows/doc-check.yml"
  ".github/workflows/quality-gates.yml"
  "scripts/dev/install-git-hooks.sh"
  "scripts/docs/index-check.sh"
  "scripts/docs/rule-files-check.sh"
  "scripts/docs/git-governance-sync-check.sh"
  "docs/02-架构/工程治理/Git门禁与模板对照清单.md"
  "docs/02-架构/工程治理/分支与门禁落地.md"
  "docs/02-架构/工程治理/工程治理与门禁.md"
  "AGENTS.md"
)

for f in "${required_files[@]}"; do
  require_file "${f}"
done

require_exec ".githooks/pre-commit"
require_exec ".githooks/commit-msg"
require_exec ".githooks/pre-push"
require_exec "scripts/dev/install-git-hooks.sh"

for hook in pre-commit commit-msg pre-push; do
  grep -F "\${hooks_path}/${hook}" scripts/dev/install-git-hooks.sh >/dev/null \
    || fail "install-git-hooks.sh 未声明必需 hook：\${hooks_path}/${hook}"
done

grep -F '.github/commit_message_template.md' scripts/dev/install-git-hooks.sh >/dev/null \
  || fail "install-git-hooks.sh 未配置 commit.template=.github/commit_message_template.md"

mapfile -t hook_headers < <(extract_commit_headers_from_hook)
mapfile -t template_headers < <(extract_commit_headers_from_template)

if [ "${#hook_headers[@]}" -eq 0 ]; then
  fail "未从 .githooks/commit-msg 解析到 required_headers"
fi
if [ "${#template_headers[@]}" -eq 0 ]; then
  fail "未从 .github/commit_message_template.md 解析到段落标题"
fi

if ! diff -u <(printf '%s\n' "${hook_headers[@]}") <(printf '%s\n' "${template_headers[@]}") >/dev/null; then
  echo "[git-governance][$(now)] commit-msg required_headers 与提交模板段落不一致：" >&2
  diff -u <(printf '%s\n' "${hook_headers[@]}") <(printf '%s\n' "${template_headers[@]}") >&2 || true
  exit 1
fi

mapfile -t workflow_sections < <(extract_pr_sections_from_workflow)
mapfile -t template_sections < <(extract_pr_sections_from_template)

if [ "${#workflow_sections[@]}" -eq 0 ]; then
  fail "未从 .github/workflows/doc-check.yml 解析到 PR required_sections"
fi
if [ "${#template_sections[@]}" -eq 0 ]; then
  fail "未从 .github/pull_request_template.md 解析到 PR 标题"
fi

if ! diff -u <(printf '%s\n' "${workflow_sections[@]}") <(printf '%s\n' "${template_sections[@]}") >/dev/null; then
  echo "[git-governance][$(now)] PR 模板标题与 doc-check required_sections 不一致：" >&2
  diff -u <(printf '%s\n' "${workflow_sections[@]}") <(printf '%s\n' "${template_sections[@]}") >&2 || true
  exit 1
fi

process_doc="docs/02-架构/工程治理/分支与门禁落地.md"
source_doc="docs/02-架构/工程治理/Git门禁与模板对照清单.md"

require_in_file "唯一信息源" "${process_doc}"
require_in_file "Git门禁与模板对照清单.md" "${process_doc}"
require_in_file "quality-gates" "${process_doc}"
require_in_file "checks" "${process_doc}"

for detail in \
  "HELIOS_ALLOW_COMMIT_MAIN" \
  "HELIOS_ALLOW_RELAXED_COMMIT_MSG" \
  "HELIOS_ALLOW_NON_ZH_COMMIT_MSG" \
  "HELIOS_ALLOW_PUSH_MAIN" \
  "git push --no-verify" \
  "scripts/docs/rule-files-check.sh" \
  "scripts/docs/git-governance-sync-check.sh"; do
  forbid_in_file "${detail}" "${process_doc}"
done

for required in \
  "pre-commit" \
  "commit-msg" \
  "pre-push" \
  "scripts/docs/index-check.sh" \
  "scripts/docs/rule-files-check.sh" \
  "scripts/docs/git-governance-sync-check.sh" \
  "scripts/ci/verify.sh" \
  "scripts/cap/verify.sh CAP-00X" \
  "HELIOS_ALLOW_COMMIT_MAIN" \
  "HELIOS_ALLOW_RELAXED_COMMIT_MSG" \
  "HELIOS_ALLOW_NON_ZH_COMMIT_MSG" \
  "HELIOS_ALLOW_PUSH_MAIN" \
  "git push --no-verify" \
  "quality-gates" \
  "checks"; do
  require_in_file "${required}" "${source_doc}"
done

for session_rule in \
  "会话可见输出规则" \
  "commit 阶段" \
  "push 阶段" \
  "PR 阶段"; do
  require_in_file "${session_rule}" "${source_doc}"
done

require_in_file "功能与文件映射:" "AGENTS.md"
require_in_file "协作会话中同步打印结构化明细" "AGENTS.md"
require_in_file "提交标题与关键说明默认使用中文" "AGENTS.md"
require_in_file "Feature-File Mapping" "docs/02-架构/工程治理/工程治理与门禁.md"
require_in_file "git-governance-sync-check.sh" "docs/02-架构/工程治理/工程治理与门禁.md"
require_in_file "协作会话中必须打印提交结构化明细" "docs/02-架构/工程治理/工程治理与门禁.md"
require_in_file "提交标题与关键说明默认使用中文" "docs/02-架构/工程治理/工程治理与门禁.md"
require_in_file "协作会话同步打印 PR 结构化明细" "${process_doc}"

log "校验通过"

#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"
source "${here}/_lib.sh"

td_id="${1:-}"
[ -n "${td_id}" ] || { wf_help; exit 1; }
WF_TD_ID="${td_id}"

wf_ensure_map_exists
cap_id="$(wf_get_field "${td_id}" cap_id || true)"
branch_prefix="$(wf_get_field "${td_id}" branch_prefix || true)"
acceptance_cmds="$(wf_get_field "${td_id}" acceptance_cmds || true)"
required_docs="$(wf_get_field "${td_id}" required_docs || true)"
tech_debt_file="$(awk -F': ' '/^[[:space:]]*tech_debt_file:/ {print $2; exit}' "$(wf_map_file)")"

if [ -z "${cap_id}" ] || [ -z "${branch_prefix}" ]; then
  wf_log "未在 workflow-map 中找到条目：${td_id}" >&2
  exit 1
fi

branch_name="${branch_prefix}-$(date -u +%Y%m%d)"
current_branch="$(git branch --show-current)"
if [ "${current_branch}" = "main" ]; then
  git checkout -b "${branch_name}"
  wf_log "已从 main 创建工作分支：${branch_name}"
else
  wf_log "当前分支为 ${current_branch}，跳过自动建分支。"
fi

today="$(wf_now_date)"
wf_update_td_open_row "${td_id}" "In Progress" "${today}" "工作流已启动（${today}）" "${tech_debt_file}"

out_dir="$(wf_artifact_dir "${td_id}")"
{
  echo "# Workflow Start Checklist"
  echo
  echo "- TD: ${td_id}"
  echo "- CAP: ${cap_id}"
  echo "- Date: ${today}"
  echo "- Branch: $(git branch --show-current)"
  echo
  echo "## Required Docs"
  wf_split_semicolon "${required_docs}"
  for doc in "${WF_ITEMS[@]}"; do
    [ -n "${doc}" ] || continue
    echo "- [ ] ${doc}"
  done
  echo
  echo "## Acceptance Commands"
  wf_split_semicolon "${acceptance_cmds}"
  for cmd in "${WF_ITEMS[@]}"; do
    [ -n "${cmd}" ] || continue
    echo "- [ ] \`${cmd}\`"
  done
} > "${out_dir}/checklist.md"

wf_log "启动完成：${td_id}"
wf_log "已更新技术债状态为 In Progress：${tech_debt_file}"
wf_log "检查清单：${out_dir}/checklist.md"
wf_log "下一步：scripts/workflow/progress.sh ${td_id}"

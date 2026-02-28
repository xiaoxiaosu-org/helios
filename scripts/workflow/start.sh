#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"
source "${here}/_lib.sh"

input_id="${1:-}"
[ -n "${input_id}" ] || { wf_help; exit 1; }
work_item_id="$(wf_resolve_work_item_id "${input_id}" || true)"
[ -n "${work_item_id}" ] || {
  wf_log "WorkItem 不存在或编号非法（要求 WI-PLANYYYYMMDDNN-NN）：${input_id}" >&2
  exit 1
}
WF_WORK_ITEM_ID="${work_item_id}"

wf_ensure_backlog_exists
status="$(wf_get_field "${work_item_id}" status || echo "todo")"
branch_prefix="$(wf_get_field "${work_item_id}" branch_prefix || true)"
required_docs="$(wf_get_field "${work_item_id}" required_docs || true)"
acceptance_cmds="$(wf_get_field "${work_item_id}" acceptance_cmds || true)"
legacy_id="$(wf_get_field "${work_item_id}" legacy_id || true)"

if [ "${status}" = "done" ]; then
  wf_log "当前 WorkItem 已是 done，禁止重复启动：${work_item_id}" >&2
  exit 1
fi

wf_append_event "${work_item_id}" "workflow.start.requested" "running" "启动工作流：${work_item_id}" "{}"

current_branch="$(git branch --show-current)"
if [ -n "${branch_prefix}" ] && [ "${current_branch}" = "main" ]; then
  branch_name="${branch_prefix}-$(date -u +%Y%m%d)"
  git checkout -b "${branch_name}"
  wf_log "已从 main 创建工作分支：${branch_name}"
else
  wf_log "当前分支为 ${current_branch}，跳过自动建分支。"
fi

today="$(wf_now_date)"
wf_update_work_item_status "${work_item_id}" "in_progress" "${today}" "工作流已启动（${today}）"

out_dir="$(wf_artifact_dir "${work_item_id}")"
WF_RUN_DIR="${out_dir}"
export WF_RUN_DIR
{
  echo "# Workflow Start Checklist"
  echo
  echo "- WorkItem: ${work_item_id}"
  echo "- Legacy: ${legacy_id:--}"
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

wf_log "启动完成：${work_item_id}"
wf_log "检查清单：${out_dir}/checklist.md"
wf_log "下一步：scripts/workflow/progress.sh ${work_item_id}"
wf_append_event "${work_item_id}" "workflow.start.completed" "pass" "启动完成" "{\"checklist\":\"${out_dir}/checklist.md\",\"branch\":\"$(git branch --show-current)\"}"

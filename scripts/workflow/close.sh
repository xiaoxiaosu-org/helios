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
required_docs="$(wf_get_field "${work_item_id}" required_docs || true)"
close_checks="$(wf_get_field "${work_item_id}" close_checks || true)"
legacy_id="$(wf_get_field "${work_item_id}" legacy_id || true)"
today="$(wf_now_date)"

wf_append_event "${work_item_id}" "workflow.close.started" "running" "开始闭环校验" "{}"

wf_log "执行闭环前推进检查"
"${here}/progress.sh" "${work_item_id}"

wf_split_semicolon "${required_docs}"
for doc in "${WF_ITEMS[@]}"; do
  [ -n "${doc}" ] || continue
  if [ ! -f "${doc}" ]; then
    wf_log "闭环失败：缺少必需文档 ${doc}" >&2
    wf_append_event "${work_item_id}" "workflow.close.failed" "failed" "缺少必需文档: ${doc}"
    exit 1
  fi
done

dependencies_done="$(wf_get_close_check_flag "${close_checks}" "dependencies_done")"
if [ "${dependencies_done}" = "true" ]; then
  dep=""
  if ! dep="$(wf_all_dependencies_done "${work_item_id}" 2>/dev/null)"; then
    dep="${dep:-<unknown>}"
    wf_log "闭环失败：依赖 WorkItem 未完成 ${dep}" >&2
    wf_append_event "${work_item_id}" "workflow.close.failed" "failed" "依赖未完成: ${dep}"
    exit 1
  fi
fi

adr_required="$(wf_get_close_check_flag "${close_checks}" "adr_required")"
if [ "${adr_required}" = "true" ] && [ -n "${legacy_id}" ]; then
  if ! wf_has_adr_for_legacy "${legacy_id}"; then
    wf_log "闭环失败：ADR 索引未检测到 ${legacy_id} 相关记录（要求 adr_required=true）。" >&2
    wf_append_event "${work_item_id}" "workflow.close.failed" "failed" "ADR 索引缺少记录: ${legacy_id}"
    exit 1
  fi
fi

move_to_done="$(wf_get_close_check_flag "${close_checks}" "move_to_done")"
if [ "${move_to_done}" = "true" ]; then
  wf_update_work_item_status "${work_item_id}" "done" "${today}" "闭环完成（${today}）"
else
  wf_update_work_item_status "${work_item_id}" "in_progress" "${today}" "闭环校验通过（${today}）"
fi

out_dir="$(wf_artifact_dir "${work_item_id}")"
WF_RUN_DIR="${out_dir}"
export WF_RUN_DIR
{
  echo "WorkItem: ${work_item_id}"
  echo "Legacy: ${legacy_id:--}"
  echo "Date: ${today}"
  echo "Required docs: ${required_docs:-<none>}"
  echo "Close checks: ${close_checks:-<none>}"
  echo "Result: PASS"
} > "${out_dir}/close-report.txt"

wf_log "闭环完成：${work_item_id}"
wf_log "闭环报告：${out_dir}/close-report.txt"
wf_append_event "${work_item_id}" "workflow.close.completed" "pass" "闭环完成" "{\"report\":\"${out_dir}/close-report.txt\"}"

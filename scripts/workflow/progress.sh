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
acceptance_cmds="$(wf_get_field "${work_item_id}" acceptance_cmds || true)"
status="$(wf_get_field "${work_item_id}" status || echo "todo")"

out_dir="$(wf_artifact_dir "${work_item_id}")"
WF_RUN_DIR="${out_dir}"
export WF_RUN_DIR
report_file="${out_dir}/progress-report.txt"
: > "${report_file}"

if [ "${status}" = "todo" ]; then
  wf_update_work_item_status "${work_item_id}" "in_progress" "$(wf_now_date)" "自动推进前置更新"
fi

if [ -z "${acceptance_cmds}" ]; then
  {
    echo "通过用例：0"
    echo "失败用例：0"
    echo "报告文件：${report_file}"
    echo "说明：该 WorkItem 未定义 acceptanceCmds，视为无需执行命令。"
  } >> "${report_file}"
  wf_log "未配置 acceptanceCmds，跳过命令执行：${work_item_id}"
  wf_append_event "${work_item_id}" "workflow.progress.completed" "pass" "无验收命令，推进完成" "{\"report\":\"${report_file}\",\"passCount\":0,\"failCount\":0}"
  exit 0
fi

pass_count=0
fail_count=0
wf_append_event "${work_item_id}" "workflow.progress.started" "running" "开始执行验收命令" "{\"report\":\"${report_file}\"}"

wf_split_semicolon "${acceptance_cmds}"
for cmd in "${WF_ITEMS[@]}"; do
  cmd="$(echo "${cmd}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -n "${cmd}" ] || continue
  wf_log "执行：${cmd}" | tee -a "${report_file}" >/dev/null
  if bash -lc "${cmd}" >> "${report_file}" 2>&1; then
    pass_count=$((pass_count + 1))
    echo "[PASS] ${cmd}" >> "${report_file}"
    wf_append_event "${work_item_id}" "workflow.progress.command" "pass" "命令通过: ${cmd}"
  else
    fail_count=$((fail_count + 1))
    echo "[FAIL] ${cmd}" >> "${report_file}"
    wf_append_event "${work_item_id}" "workflow.progress.command" "failed" "命令失败: ${cmd}"
  fi
done

{
  echo "通过用例：${pass_count}"
  echo "失败用例：${fail_count}"
  echo "报告文件：${report_file}"
} >> "${report_file}"

if [ "${fail_count}" -gt 0 ]; then
  wf_log "推进失败：${fail_count} 条命令失败（报告：${report_file}）" >&2
  wf_append_event "${work_item_id}" "workflow.progress.completed" "failed" "推进失败" "{\"report\":\"${report_file}\",\"passCount\":${pass_count},\"failCount\":${fail_count}}"
  exit 1
fi

wf_log "推进完成：全部命令通过（报告：${report_file}）"
wf_log "下一步：scripts/workflow/close.sh ${work_item_id}"
wf_append_event "${work_item_id}" "workflow.progress.completed" "pass" "推进完成" "{\"report\":\"${report_file}\",\"passCount\":${pass_count},\"failCount\":${fail_count}}"

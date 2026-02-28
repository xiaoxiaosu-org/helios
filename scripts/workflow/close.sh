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
required_docs="$(wf_get_field "${td_id}" required_docs || true)"
close_checks="$(wf_get_field "${td_id}" close_checks || true)"
cap_id="$(wf_get_field "${td_id}" cap_id || true)"
tech_debt_file="$(awk -F': ' '/^[[:space:]]*tech_debt_file:/ {print $2; exit}' "$(wf_map_file)")"
today="$(wf_now_date)"

if [ -z "${required_docs}" ] || [ -z "${close_checks}" ]; then
  wf_log "未在 workflow-map 中找到 close 配置：${td_id}" >&2
  exit 1
fi

wf_log "执行闭环前推进检查"
"${here}/progress.sh" "${td_id}"

wf_split_semicolon "${required_docs}"
for doc in "${WF_ITEMS[@]}"; do
  [ -n "${doc}" ] || continue
  if [ ! -f "${doc}" ]; then
    wf_log "闭环失败：缺少必需文档 ${doc}" >&2
    exit 1
  fi
done

must_move_done="$(wf_get_close_check_flag "${close_checks}" "td_must_move_done")"
if [ "${must_move_done}" = "true" ]; then
  if ! wf_row_exists_in_done "${td_id}" "${tech_debt_file}"; then
    wf_log "闭环失败：${td_id} 未迁移到“已完成”分区（${tech_debt_file}）" >&2
    exit 1
  fi
else
  wf_update_td_open_row "${td_id}" "In Progress" "${today}" "闭环校验通过（${today}）" "${tech_debt_file}"
fi

cap_status_done="$(wf_get_close_check_flag "${close_checks}" "cap_status_done")"
if [ "${cap_status_done}" = "true" ]; then
  if [ -z "${cap_id}" ]; then
    wf_log "闭环失败：${td_id} 要求 cap_status_done=true，但 workflow-map 缺少 cap_id。" >&2
    exit 1
  fi
  cap_plan_state="$(wf_get_cap_plan_state "${cap_id}" || true)"
  if [ -z "${cap_plan_state}" ]; then
    wf_log "闭环失败：未在执行计划中找到 ${cap_id} 状态，无法校验 cap_status_done。" >&2
    exit 1
  fi
  if [ "${cap_plan_state}" != "Done" ]; then
    wf_log "闭环失败：${cap_id} 当前状态为 ${cap_plan_state}，要求 Done（见执行计划）。" >&2
    exit 1
  fi
fi

adr_required="$(wf_get_close_check_flag "${close_checks}" "adr_required")"
if [ "${adr_required}" = "true" ]; then
  if [ -z "${cap_id}" ]; then
    wf_log "闭环失败：${td_id} 要求 adr_required=true，但 workflow-map 缺少 cap_id。" >&2
    exit 1
  fi
  if ! wf_has_adr_for_cap "${cap_id}"; then
    wf_log "闭环失败：ADR 索引未检测到 ${cap_id} 相关记录（要求 adr_required=true）。" >&2
    exit 1
  fi
fi

out_dir="$(wf_artifact_dir "${td_id}")"
{
  echo "TD: ${td_id}"
  echo "Date: ${today}"
  echo "Required docs: ${required_docs}"
  echo "Close checks: ${close_checks}"
  echo "Result: PASS"
} > "${out_dir}/close-report.txt"

wf_log "闭环完成：${td_id}"
wf_log "闭环报告：${out_dir}/close-report.txt"

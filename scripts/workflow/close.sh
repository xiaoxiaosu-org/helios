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

must_move_done="$(echo "${close_checks}" | tr ',' '\n' | awk -F'=' '$1 ~ /td_must_move_done/ {print $2; exit}')"
if [ "${must_move_done}" = "true" ]; then
  if ! wf_row_exists_in_done "${td_id}" "${tech_debt_file}"; then
    wf_log "闭环失败：${td_id} 未迁移到“已完成”分区（${tech_debt_file}）" >&2
    exit 1
  fi
else
  wf_update_td_open_row "${td_id}" "In Progress" "${today}" "闭环校验通过（${today}）" "${tech_debt_file}"
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

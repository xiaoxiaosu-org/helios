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
acceptance_cmds="$(wf_get_field "${td_id}" acceptance_cmds || true)"
if [ -z "${cap_id}" ] || [ -z "${acceptance_cmds}" ]; then
  wf_log "未在 workflow-map 中找到可执行验收命令：${td_id}" >&2
  exit 1
fi

out_dir="$(wf_artifact_dir "${td_id}")"
report_file="${out_dir}/progress-report.txt"
: > "${report_file}"

pass_count=0
fail_count=0

wf_split_semicolon "${acceptance_cmds}"
for cmd in "${WF_ITEMS[@]}"; do
  cmd="$(echo "${cmd}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -n "${cmd}" ] || continue
  wf_log "执行：${cmd}" | tee -a "${report_file}" >/dev/null
  if bash -lc "${cmd}" >> "${report_file}" 2>&1; then
    pass_count=$((pass_count + 1))
    echo "[PASS] ${cmd}" >> "${report_file}"
  else
    fail_count=$((fail_count + 1))
    echo "[FAIL] ${cmd}" >> "${report_file}"
  fi
done

{
  echo "通过用例：${pass_count}"
  echo "失败用例：${fail_count}"
  echo "报告文件：${report_file}"
} >> "${report_file}"

if [ "${fail_count}" -gt 0 ]; then
  wf_log "推进失败：${fail_count} 条命令失败（报告：${report_file}）" >&2
  exit 1
fi

wf_log "推进完成：全部命令通过（报告：${report_file}）"
wf_log "下一步：scripts/workflow/close.sh ${td_id}"

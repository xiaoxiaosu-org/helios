#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "${here}/../.." && pwd)"
cd "${root}"

usage() {
  echo "用法：scripts/cap/verify.sh CAP-001" >&2
  exit 3
}

[ "${1:-}" != "" ] || usage
cap_id="$1"

if ! echo "${cap_id}" | grep -Eq '^CAP-[0-9]{3}$'; then
  echo "[cap] CAP ID 不合法：${cap_id}" >&2
  exit 3
fi

source "${here}/_lib.sh"

run_dir="$(cap_mkdir_run_dir "${cap_id}")"
export ARTIFACT_DIR="${run_dir}"
export CAP_ID="${cap_id}"

cap_script="${here}/${cap_id}/verify.sh"
cmd_str="scripts/cap/verify.sh ${cap_id}"

{
  cap_log "启动：CAP 验收"
  cap_log "产物目录：${run_dir}"
  cap_log "验收脚本：${cap_script}"
} | tee "${run_dir}/run.log" >/dev/null

exit_code=0

if [ ! -x "${cap_script}" ]; then
  cap_log "阻塞：缺少或不可执行 ${cap_script}" | tee -a "${run_dir}/run.log" >/dev/null
  exit_code=2
else
  # Run CAP-specific checks; it is responsible for writing any additional artifacts under $ARTIFACT_DIR.
  set +e
  "${cap_script}" 2>&1 | tee -a "${run_dir}/run.log"
  exit_code="${PIPESTATUS[0]}"
  set -e
fi

status="$(cap_status_from_exit_code "${exit_code}")"
cap_write_meta "${run_dir}" "${cap_id}" "${cmd_str}" "${exit_code}" "${status}"

if [ "${exit_code}" -eq 0 ]; then
  cap_log "结束：成功（返回码 ${exit_code}）" | tee -a "${run_dir}/run.log" >/dev/null
  cap_log "下一步：${cap_id} 已通过，建议立即进入提交与 PR 闭环（禁止在 main 直接提交）。" | tee -a "${run_dir}/run.log" >/dev/null
  cap_log "下一步：在会话输出结构化提交明细后提交；PR 描述中引用证据目录：${run_dir}" | tee -a "${run_dir}/run.log" >/dev/null
else
  cap_log "结束：失败/阻塞（返回码 ${exit_code}）" | tee -a "${run_dir}/run.log" >/dev/null
fi

exit "${exit_code}"

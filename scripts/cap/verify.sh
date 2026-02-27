#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "${here}/../.." && pwd)"
cd "${root}"

usage() {
  echo "Usage: scripts/cap/verify.sh CAP-001" >&2
  exit 3
}

[ "${1:-}" != "" ] || usage
cap_id="$1"

if ! echo "${cap_id}" | grep -Eq '^CAP-[0-9]{3}$'; then
  echo "[cap] invalid cap id: ${cap_id}" >&2
  exit 3
fi

source "${here}/_lib.sh"

run_dir="$(cap_mkdir_run_dir "${cap_id}")"
export ARTIFACT_DIR="${run_dir}"

cap_script="${here}/${cap_id}/verify.sh"
cmd_str="scripts/cap/verify.sh ${cap_id}"

{
  echo "[cap] capId=${cap_id}"
  echo "[cap] artifactDir=${run_dir}"
  echo "[cap] script=${cap_script}"
} | tee "${run_dir}/run.log" >/dev/null

exit_code=0

if [ ! -x "${cap_script}" ]; then
  echo "[cap] blocked: missing or non-executable ${cap_script}" | tee -a "${run_dir}/run.log" >/dev/null
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

exit "${exit_code}"


#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"
source "${here}/_lib.sh"

ci_begin "CAP 路线图状态与验收结果一致性检查"

out_dir="artifacts/ci/cap-plan-sync"
strict="true"

while [ $# -gt 0 ]; do
  case "$1" in
    --out)
      out_dir="${2:-}"
      shift 2
      ;;
    --allow-drift)
      strict="false"
      shift
      ;;
    *)
      echo "用法：scripts/ci/cap-plan-sync-check.sh [--out <dir>] [--allow-drift]" >&2
      exit 1
      ;;
  esac
done

map_file="docs/02-架构/执行计划/workflow-map.yaml"
plan_file="docs/02-架构/执行计划/active/PLAN-20260227-工程智能化路线图.md"
if [ -f "${map_file}" ]; then
  mapped_plan="$(awk -F': ' '/^[[:space:]]*plan_file:/ {print $2; exit}' "${map_file}")"
  if [ -n "${mapped_plan}" ]; then
    plan_file="${mapped_plan}"
  fi
fi

[ -f "${plan_file}" ] || {
  echo "[cap-sync] 缺少路线图文件：${plan_file}" >&2
  exit 1
}

mkdir -p "${out_dir}"
report_txt="${out_dir}/cap-plan-sync-report.txt"
report_md="${out_dir}/cap-plan-sync-summary.md"
status_tsv="${out_dir}/cap-status.tsv"
drift_file="${out_dir}/drift.txt"
: > "${report_txt}"
: > "${status_tsv}"
: > "${drift_file}"

awk -F'|' '/^\| CAP-[0-9]{3} / {
  cap=$2; state=$7;
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", cap);
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", state);
  print cap "|" state;
}' "${plan_file}" | while IFS='|' read -r cap_id plan_state; do
  [ -n "${cap_id}" ] || continue
  cap_log_file="${out_dir}/${cap_id}.log"

  set +e
  scripts/cap/verify.sh "${cap_id}" > "${cap_log_file}" 2>&1
  rc=$?
  set -e

  runtime_state="unknown"
  case "${rc}" in
    0) runtime_state="pass" ;;
    1) runtime_state="fail" ;;
    2) runtime_state="blocked" ;;
    3) runtime_state="error" ;;
  esac

  sync_state="in-sync"
  sync_reason=""
  if [ "${plan_state}" = "Done" ] && [ "${rc}" -ne 0 ]; then
    sync_state="drift"
    sync_reason="路线图=Done 但验收返回非0"
  fi
  if [ "${plan_state}" != "Done" ] && [ "${rc}" -eq 0 ]; then
    sync_state="drift"
    sync_reason="路线图!=Done 但验收返回0"
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' "${cap_id}" "${plan_state}" "${runtime_state}" "${rc}" "${sync_state}" >> "${status_tsv}"
  printf '%s plan=%s runtime=%s rc=%s sync=%s\n' "${cap_id}" "${plan_state}" "${runtime_state}" "${rc}" "${sync_state}" >> "${report_txt}"

  if [ "${sync_state}" = "drift" ]; then
    printf '%s: %s\n' "${cap_id}" "${sync_reason}" >> "${drift_file}"
  fi
done

drift_count="$(wc -l < "${drift_file}" | tr -d ' ')"

{
  echo "# CAP 状态同步报告"
  echo
  echo "- 路线图: ${plan_file}"
  echo "- 严格模式: ${strict}"
  echo "- 漂移项: ${drift_count}"
  echo
  echo "| CAP | 路线图状态 | 验收结果 | 返回码 | 同步状态 |"
  echo "|---|---|---|---|---|"
  while IFS=$'\t' read -r cap_id plan_state runtime_state rc sync_state; do
    [ -n "${cap_id}" ] || continue
    printf '| %s | %s | %s | %s | %s |\n' "${cap_id}" "${plan_state}" "${runtime_state}" "${rc}" "${sync_state}"
  done < "${status_tsv}"

  if [ "${drift_count}" -gt 0 ]; then
    echo
    echo "## 漂移详情"
    sed 's/^/- /' "${drift_file}"
  fi
} > "${report_md}"

if [ "${drift_count}" -gt 0 ] && [ "${strict}" = "true" ]; then
  cat "${report_md}" >&2
  echo "[cap-sync] 失败：检测到状态漂移，请同步更新路线图状态或修复 CAP 验收脚本。" >&2
  exit 1
fi

log "通过：CAP 状态一致性检查完成（报告：${report_md}）"

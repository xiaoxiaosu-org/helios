#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"
source "${here}/_lib.sh"

out_dir="artifacts/ci/tech-debt-governance"
while [ $# -gt 0 ]; do
  case "$1" in
    --out)
      out_dir="${2:-}"
      shift 2
      ;;
    *)
      echo "用法：scripts/ci/tech-debt-governance-check.sh [--out <dir>]" >&2
      exit 1
      ;;
  esac
done

f="docs/02-架构/技术债清单.md"
max_stale_days="${TECH_DEBT_MAX_STALE_DAYS:-7}"

mkdir -p "${out_dir}"
report_file="${out_dir}/tech-debt-governance-check.txt"
: > "${report_file}"

fail() {
  echo "$1" | tee -a "${report_file}" >&2
  exit 1
}

echo "[tech-debt] 检查文件：${f}" | tee -a "${report_file}" >/dev/null

[ -f "${f}" ] || fail "[tech-debt] 缺少文件：${f}"

if ! rg -n "^\\| ID \\| 标题 \\| 影响面 \\| 优先级 \\| 验收标准 \\| 状态 \\| 最近更新 \\| 备注 \\|$" "${f}" >/dev/null; then
  fail "[tech-debt] 在制技术债表头不符合要求（必须移除 Owner 列并保留关键字段）。"
fi

if rg -n "\\| Owner \\|" "${f}" >/dev/null; then
  fail "[tech-debt] 检测到 Owner 列，单人开发模式下不允许该字段。"
fi

if ! rg -n '状态枚举：`Open` / `In Progress` / `Blocked` / `Done`' "${f}" >/dev/null; then
  fail "[tech-debt] 缺少状态枚举声明。"
fi

today_epoch="$(date -u +%s)"
has_td=0

if ! rg -n '^\| TD-[0-9]{3} ' "${f}" >/dev/null; then
  fail "[tech-debt] 未检测到任何 TD 记录。"
fi

while IFS=$'\t' read -r line_no section td_id status last_update note; do
  has_td=1
  case "${status}" in
    "Open"|"In Progress"|"Blocked"|"Done")
      ;;
    *)
      fail "[tech-debt] 第 ${line_no} 行状态非法：${status}"
      ;;
  esac

  if [ "${section}" = "open" ] && [ "${status}" = "Done" ]; then
    fail "[tech-debt] 第 ${line_no} 行状态为 Done，但仍在“在制技术债”分区。"
  fi

  if ! echo "${last_update}" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    fail "[tech-debt] 第 ${line_no} 行最近更新日期格式非法：${last_update}（应为 YYYY-MM-DD）"
  fi

  update_epoch="$(date -u -d "${last_update}" +%s 2>/dev/null || true)"
  [ -n "${update_epoch}" ] || fail "[tech-debt] 第 ${line_no} 行最近更新日期不可解析：${last_update}"

  age_days=$(( (today_epoch - update_epoch) / 86400 ))
  if [ "${section}" = "open" ] && [ "${age_days}" -gt "${max_stale_days}" ]; then
    if ! echo "${note}" | grep -q "阻塞原因"; then
      fail "[tech-debt] 第 ${line_no} 行超期 ${age_days} 天（阈值 ${max_stale_days}），备注缺少“阻塞原因”。"
    fi
    if ! echo "${note}" | grep -q "下一步"; then
      fail "[tech-debt] 第 ${line_no} 行超期 ${age_days} 天（阈值 ${max_stale_days}），备注缺少“下一步”。"
    fi
  fi
done < <(
  awk -F'|' '
    BEGIN { section="none" }
    /^## 在制技术债/ { section="open"; next }
    /^## 已完成/ { section="done"; next }
    section == "open" && /^\| TD-[0-9]{3} / {
      line_no=NR
      id=$2; status=$7; last_update=$8; note=$9
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", last_update)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", note)
      printf "%s\t%s\t%s\t%s\t%s\t%s\n", line_no, section, id, status, last_update, note
    }
  ' "${f}"
)

[ "${has_td}" -eq 1 ] || fail "[tech-debt] 在制技术债分区未检测到任何 TD 记录。"

{
  echo "[tech-debt] 通过：字段结构、状态合法性、分区约束、超期说明检查通过"
  echo "[tech-debt] 超期阈值：${max_stale_days} 天"
} | tee -a "${report_file}" >/dev/null

log "通过：技术债治理检查通过（报告：${report_file}）"

#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"
source "${here}/_lib.sh"

usage() {
  cat <<'__USAGE__'
用法：
  scripts/workflow/multi-plan-autopilot.sh \
    --plans PLAN-YYYYMMDD-NN[,PLAN-YYYYMMDD-NN...] \
    [--max-items-per-plan 1] \
    [--handoff-dir artifacts/workflow/handoffs] \
    [--continue-on-error]

说明：
  1. 按计划顺序自动推进待执行 WorkItem。
  2. 每个计划优先处理 in_progress，其次 todo（再按优先级与编号排序）。
  3. 每个计划结束后自动生成 handoff 文件，可直接作为下一会话启动输入。
__USAGE__
}

plans_raw=""
max_items_per_plan="1"
handoff_dir="artifacts/workflow/handoffs"
continue_on_error="false"

while [ $# -gt 0 ]; do
  case "$1" in
    --plans) plans_raw="${2:-}"; shift 2 ;;
    --max-items-per-plan) max_items_per_plan="${2:-}"; shift 2 ;;
    --handoff-dir) handoff_dir="${2:-}"; shift 2 ;;
    --continue-on-error) continue_on_error="true"; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 1 ;;
  esac
done

[ -n "${plans_raw}" ] || { echo "缺少 --plans" >&2; usage; exit 1; }
echo "${max_items_per_plan}" | grep -Eq '^[0-9]+$' || {
  echo "--max-items-per-plan 必须是数字" >&2
  exit 1
}
[ "${max_items_per_plan}" -gt 0 ] || {
  echo "--max-items-per-plan 必须大于 0" >&2
  exit 1
}

wf_ensure_backlog_exists

run_id="$(wf_now_compact)-$(git rev-parse --short HEAD 2>/dev/null || echo nogit)"
run_dir="artifacts/workflow/autopilot/${run_id}"
mkdir -p "${run_dir}" "${handoff_dir}"
summary_file="${run_dir}/summary.md"
result_tsv="${run_dir}/result.tsv"
: > "${result_tsv}"

normalize_plans() {
  echo "$1" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d'
}

pending_for_plan_tsv() {
  local plan_id="$1"
  local limit="$2"
  node -e '
const fs = require("node:fs");
const planId = process.argv[1];
const limit = Number(process.argv[2]);
const data = JSON.parse(fs.readFileSync("docs/02-架构/执行计划/backlog.yaml", "utf8"));
const items = (data.workItems || []).filter((x) =>
  String(x.planId || "") === planId && ["todo", "in_progress"].includes(String(x.status || ""))
);
const statusRank = (s) => (s === "in_progress" ? 0 : 1);
const priorityRank = (p) => {
  const m = String(p || "").match(/^P([0-9]+)$/i);
  return m ? Number(m[1]) : 99;
};
items.sort((a, b) => {
  const sr = statusRank(a.status) - statusRank(b.status);
  if (sr !== 0) return sr;
  const pr = priorityRank(a.priority) - priorityRank(b.priority);
  if (pr !== 0) return pr;
  return String(a.workItemId || "").localeCompare(String(b.workItemId || ""));
});
for (const item of items.slice(0, limit)) {
  const title = String(item.title || "").replace(/\s+/g, " ").trim();
  process.stdout.write(`${item.workItemId}\t${item.status}\t${item.priority || ""}\t${title}\n`);
}
' "${plan_id}" "${limit}"
}

next_pending_for_plan_tsv() {
  local plan_id="$1"
  node -e '
const fs = require("node:fs");
const planId = process.argv[1];
const data = JSON.parse(fs.readFileSync("docs/02-架构/执行计划/backlog.yaml", "utf8"));
const items = (data.workItems || []).filter((x) =>
  String(x.planId || "") === planId && ["todo", "in_progress"].includes(String(x.status || ""))
);
if (items.length === 0) process.exit(0);
const statusRank = (s) => (s === "in_progress" ? 0 : 1);
const priorityRank = (p) => {
  const m = String(p || "").match(/^P([0-9]+)$/i);
  return m ? Number(m[1]) : 99;
};
items.sort((a, b) => {
  const sr = statusRank(a.status) - statusRank(b.status);
  if (sr !== 0) return sr;
  const pr = priorityRank(a.priority) - priorityRank(b.priority);
  if (pr !== 0) return pr;
  return String(a.workItemId || "").localeCompare(String(b.workItemId || ""));
});
const first = items[0];
const title = String(first.title || "").replace(/\s+/g, " ").trim();
process.stdout.write(`${first.workItemId}\t${first.status}\t${first.priority || ""}\t${title}\t${items.length}\n`);
' "${plan_id}"
}

run_phases_for_work_item() {
  local work_item_id="$1"
  local current_status="$2"
  local plan_id="$3"

  local phases=()
  if [ "${current_status}" = "todo" ]; then
    phases=("start" "progress" "close")
  elif [ "${current_status}" = "in_progress" ]; then
    phases=("progress" "close")
  else
    phases=()
  fi

  local phase
  for phase in "${phases[@]}"; do
    wf_log "[autopilot] ${plan_id} ${work_item_id} -> ${phase}"
    if scripts/workflow/run.sh "${work_item_id}" "${phase}"; then
      printf '%s\t%s\t%s\t%s\t%s\n' "${plan_id}" "${work_item_id}" "${phase}" "pass" "" >> "${result_tsv}"
    else
      printf '%s\t%s\t%s\t%s\t%s\n' "${plan_id}" "${work_item_id}" "${phase}" "failed" "执行失败" >> "${result_tsv}"
      if [ "${continue_on_error}" != "true" ]; then
        return 1
      fi
      return 0
    fi
  done
  return 0
}

generate_handoff_file() {
  local plan_id="$1"
  local plan_out="${handoff_dir}/${plan_id}-${run_id}.md"
  local next_line
  next_line="$(next_pending_for_plan_tsv "${plan_id}" || true)"

  local next_wi=""
  local next_status=""
  local next_priority=""
  local next_title=""
  local remaining="0"
  if [ -n "${next_line}" ]; then
    IFS=$'\t' read -r next_wi next_status next_priority next_title remaining <<< "${next_line}"
  fi

  {
    echo "# ${plan_id} 自动推进交接卡"
    echo
    echo "- 生成时间：$(wf_now)"
    echo "- Run ID：${run_id}"
    echo "- 计划：${plan_id}"
    echo
    echo "## 本轮执行记录"
    echo
    echo "| WorkItem | 阶段 | 结果 |"
    echo "|---|---|---|"
    awk -F'\t' -v p="${plan_id}" '$1==p {printf("| %s | %s | %s |\n",$2,$3,$4)}' "${result_tsv}"
    echo
    echo "## 下一步建议"
    echo
    if [ -n "${next_wi}" ]; then
      echo "- remaining: ${remaining}"
      echo "- next: ${next_wi} (${next_status}/${next_priority}) ${next_title}"
      echo
      echo "建议在新会话输入："
      echo
      echo '```text'
      echo "继续推进 ${plan_id}，优先执行 ${next_wi}（${next_status}/${next_priority}）。"
      echo "请按 scripts/workflow/run.sh ${next_wi} full 执行并回报结构化结果。"
      echo '```'
    else
      echo "- remaining: 0"
      echo "- 当前计划已无待执行 WorkItem。"
    fi
  } > "${plan_out}"

  wf_log "[autopilot] handoff 已生成：${plan_out}"
}

{
  echo "# 多计划自动推进摘要"
  echo
  echo "- Run ID: ${run_id}"
  echo "- 计划列表: ${plans_raw}"
  echo "- 每计划最大推进项: ${max_items_per_plan}"
  echo "- 失败是否继续: ${continue_on_error}"
  echo
} > "${summary_file}"

mapfile -t plans < <(normalize_plans "${plans_raw}")

if [ "${#plans[@]}" -eq 0 ]; then
  echo "--plans 解析后为空" >&2
  exit 1
fi

for plan_id in "${plans[@]}"; do
  wf_log "[autopilot] 开始计划：${plan_id}"
  echo "## ${plan_id}" >> "${summary_file}"
  echo >> "${summary_file}"
  echo "| WorkItem | 初始状态 | 优先级 | 标题 |" >> "${summary_file}"
  echo "|---|---|---|---|" >> "${summary_file}"

  mapfile -t rows < <(pending_for_plan_tsv "${plan_id}" "${max_items_per_plan}")
  if [ "${#rows[@]}" -eq 0 ]; then
    echo "| - | - | - | 无待执行项 |" >> "${summary_file}"
    echo >> "${summary_file}"
    generate_handoff_file "${plan_id}"
    continue
  fi

  for row in "${rows[@]}"; do
    IFS=$'\t' read -r wi status priority title <<< "${row}"
    echo "| ${wi} | ${status} | ${priority} | ${title} |" >> "${summary_file}"
    if ! run_phases_for_work_item "${wi}" "${status}" "${plan_id}"; then
      echo >> "${summary_file}"
      echo "- 结果：失败（中止）" >> "${summary_file}"
      generate_handoff_file "${plan_id}"
      wf_log "[autopilot] 失败中止：${plan_id} ${wi}"
      exit 1
    fi
  done
  echo >> "${summary_file}"
  echo "- 结果：完成" >> "${summary_file}"
  echo >> "${summary_file}"
  generate_handoff_file "${plan_id}"
done

wf_log "[autopilot] 全部计划执行完成"
wf_log "[autopilot] 摘要：${summary_file}"
wf_log "[autopilot] 交接目录：${handoff_dir}"

#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"
source "${here}/_lib.sh"

usage() {
  cat <<'__USAGE__'
用法：
  scripts/workflow/plan-add.sh \
    --title "计划标题" \
    [--owner "repo-owner"] \
    [--seed-title "初始化 WorkItem 标题"] \
    [--seed-kind initiative|capability|task|debt] \
    [--seed-priority P2] \
    [--seed-status todo|in_progress|blocked|done]

说明：
  1. 自动生成当日唯一 planId（PLAN-YYYYMMDD-NN）。
  2. 自动创建首个 WorkItem（默认 initiative），保证计划文档与 backlog 可立即通过门禁。
  3. 自动回填 docs/02-架构/执行计划/README.md 的 active 索引。
__USAGE__
}

title=""
owner="repo-owner"
seed_title="计划初始化（待拆解）"
seed_kind="initiative"
seed_priority="P2"
seed_status="todo"

while [ $# -gt 0 ]; do
  case "$1" in
    --title) title="${2:-}"; shift 2 ;;
    --owner) owner="${2:-}"; shift 2 ;;
    --seed-title) seed_title="${2:-}"; shift 2 ;;
    --seed-kind) seed_kind="${2:-}"; shift 2 ;;
    --seed-priority) seed_priority="${2:-}"; shift 2 ;;
    --seed-status) seed_status="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 1 ;;
  esac
done

[ -n "${title}" ] || { echo "缺少 --title" >&2; usage; exit 1; }
[ -n "${owner}" ] || { echo "--owner 不能为空" >&2; exit 1; }

case "${seed_kind}" in
  initiative|capability|task|debt) ;;
  *) echo "--seed-kind 必须是 initiative|capability|task|debt" >&2; exit 1 ;;
esac

case "${seed_status}" in
  todo|in_progress|blocked|done) ;;
  *) echo "--seed-status 必须是 todo|in_progress|blocked|done" >&2; exit 1 ;;
esac

if ! echo "${seed_priority}" | grep -Eq '^P[0-9]+$'; then
  echo "--seed-priority 必须为 P0/P1/..." >&2
  exit 1
fi

wf_ensure_backlog_exists

plan_root="docs/02-架构/执行计划"
active_dir="${plan_root}/active"
completed_dir="${plan_root}/completed"
mkdir -p "${active_dir}" "${completed_dir}"

date_token="$(date -u +%Y%m%d)"
max_seq="$({
  find "${active_dir}" "${completed_dir}" -maxdepth 1 -type f -name "PLAN-${date_token}-*.md" 2>/dev/null || true
} | sed -nE "s#.*PLAN-${date_token}-([0-9]{2})-.*#\1#p" | sort -n | tail -n 1)"

if [ -z "${max_seq}" ]; then
  max_seq="00"
fi
next_seq_num=$((10#${max_seq} + 1))
next_seq="$(printf '%02d' "${next_seq_num}")"

plan_id="PLAN-${date_token}-${next_seq}"
safe_title="$(printf '%s' "${title}" | sed -E 's#[/\\:*?"<>|]+#-#g; s/[[:space:]]+/-/g; s/^-+|-+$//g')"
if [ -z "${safe_title}" ]; then
  safe_title="未命名计划"
fi

plan_rel="${active_dir}/${plan_id}-${safe_title}.md"
if [ -f "${plan_rel}" ]; then
  echo "计划文件已存在：${plan_rel}" >&2
  exit 1
fi

set +e
wi_output="$(${here}/workitem-add.sh \
  --plan-id "${plan_id}" \
  --kind "${seed_kind}" \
  --title "${seed_title}" \
  --owner "${owner}" \
  --priority "${seed_priority}" \
  --status "${seed_status}" 2>&1)"
wi_rc=$?
set -e
if [ "${wi_rc}" -ne 0 ]; then
  echo "${wi_output}" >&2
  exit "${wi_rc}"
fi
seed_wi="$(echo "${wi_output}" | rg -o 'WI-PLAN[0-9]{10}-[0-9]{2}' | head -n 1 || true)"
if [ -z "${seed_wi}" ]; then
  echo "创建初始化 WorkItem 失败：${wi_output}" >&2
  exit 1
fi

today="$(wf_now_date)"
{
  echo "# ${plan_id}：${title}"
  echo
  echo "## 背景与目标"
  echo
  echo "- 背景："
  echo "- 问题："
  echo "- 目标："
  echo "- 非目标："
  echo
  echo "## WorkItem 清单"
  echo
  echo "状态枚举：\`todo\` / \`in_progress\` / \`blocked\` / \`done\`"
  echo
  echo "| WorkItem | 类型 | 标题 | Owner | 状态 | 验收命令 | 证据目录 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| ${seed_wi} | ${seed_kind} | ${seed_title} | ${owner} | ${seed_status} | \`scripts/workflow/run.sh ${seed_wi} progress\` | \`artifacts/workflow/\` |"
  echo
  echo "## 推进记录"
  echo
  echo "| 日期 | WorkItem | 动作 | 结果 | 备注 |"
  echo "|---|---|---|---|---|"
  echo "| ${today} | ${seed_wi} | 初始化计划 | pass | 自动创建首个 WorkItem |"
  echo
  echo "## 验收与证据"
  echo
  echo "- 统一验收入口：\`scripts/workflow/run.sh <WI-PLANYYYYMMDDNN-NN> [start|progress|close|full]\`"
  echo "- 统一证据目录：\`artifacts/workflow/<WI-ID>/<run-id>/\`"
  echo "- 事件追踪文件：\`artifacts/workflow/events/<WI-ID>.jsonl\`"
  echo
  echo "## 风险与阻塞"
  echo
  echo "- 风险："
  echo "- 阻塞："
  echo "- 解除阻塞动作："
  echo
  echo "## 下一步"
  echo
  echo "1. 补齐本计划的真实 WorkItem 拆解。"
  echo "2. 执行 \`scripts/workflow/backlog.sh check\` 与 \`scripts/ci/plan-template-check.sh\`。"
} > "${plan_rel}"

readme_file="${plan_root}/README.md"
if [ -f "${readme_file}" ] && ! grep -F "${plan_rel}" "${readme_file}" >/dev/null; then
  tmp_readme="$(mktemp)"
  awk -v entry="- ${title}：\`${plan_rel}\`" '
    BEGIN { inserted=0 }
    {
      print
      if ($0 == "## 当前计划（active）" && inserted == 0) {
        print entry
        inserted=1
      }
    }
  ' "${readme_file}" > "${tmp_readme}"
  mv "${tmp_readme}" "${readme_file}"
fi

"${here}/backlog.sh" build

wf_log "新增计划成功：${plan_id}"
wf_log "计划文件：${plan_rel}"
wf_log "初始化 WorkItem：${seed_wi}"
wf_log "建议下一步：scripts/workflow/run.sh ${seed_wi} start"

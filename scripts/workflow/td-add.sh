#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"
source "${here}/_lib.sh"

usage() {
  cat <<'EOF'
用法：
  scripts/workflow/td-add.sh \
    --title "标题" \
    --impact "影响面" \
    --priority "P1" \
    --acceptance "验收标准" \
    --cap "CAP-011" \
    [--note "备注"] \
    [--trigger-paths "scripts/ci/;src/"] \
    [--required-docs "docs/02-架构/技术债清单.md;docs/02-架构/执行计划/workflow-map.yaml"] \
    [--acceptance-cmds "scripts/cap/verify.sh CAP-011;scripts/ci/verify.sh"] \
    [--branch-prefix "cap/CAP-011"] \
    [--close-checks "td_must_move_done=false,cap_status_done=true,adr_required=false"]
EOF
}

title=""
impact=""
priority=""
acceptance=""
cap_id=""
note="-"
trigger_paths="scripts/cap/;scripts/ci/;.github/workflows/;docs/02-架构/技术债清单.md"
required_docs="docs/02-架构/技术债清单.md;docs/02-架构/执行计划/workflow-map.yaml"
acceptance_cmds=""
branch_prefix=""
close_checks="td_must_move_done=false,cap_status_done=true,adr_required=false"

while [ $# -gt 0 ]; do
  case "$1" in
    --title) title="${2:-}"; shift 2 ;;
    --impact) impact="${2:-}"; shift 2 ;;
    --priority) priority="${2:-}"; shift 2 ;;
    --acceptance) acceptance="${2:-}"; shift 2 ;;
    --cap) cap_id="${2:-}"; shift 2 ;;
    --note) note="${2:-}"; shift 2 ;;
    --trigger-paths) trigger_paths="${2:-}"; shift 2 ;;
    --required-docs) required_docs="${2:-}"; shift 2 ;;
    --acceptance-cmds) acceptance_cmds="${2:-}"; shift 2 ;;
    --branch-prefix) branch_prefix="${2:-}"; shift 2 ;;
    --close-checks) close_checks="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 1 ;;
  esac
done

[ -n "${title}" ] || { echo "缺少 --title" >&2; usage; exit 1; }
[ -n "${impact}" ] || { echo "缺少 --impact" >&2; usage; exit 1; }
[ -n "${priority}" ] || { echo "缺少 --priority" >&2; usage; exit 1; }
[ -n "${acceptance}" ] || { echo "缺少 --acceptance" >&2; usage; exit 1; }
[ -n "${cap_id}" ] || { echo "缺少 --cap" >&2; usage; exit 1; }

if ! echo "${priority}" | grep -Eq '^P[0-9]+$'; then
  echo "--priority 必须为 P0/P1/... 形式" >&2
  exit 1
fi

if ! echo "${cap_id}" | grep -Eq '^CAP-[0-9]{3}$'; then
  echo "--cap 必须为 CAP-XXX 形式" >&2
  exit 1
fi

if [ -z "${acceptance_cmds}" ]; then
  acceptance_cmds="scripts/cap/verify.sh ${cap_id};scripts/ci/verify.sh;scripts/docs/git-governance-sync-check.sh"
fi

if [ -z "${branch_prefix}" ]; then
  branch_prefix="cap/${cap_id}"
fi

map_file="$(wf_map_file)"
wf_ensure_map_exists
tech_debt_file="$(awk -F': ' '/^[[:space:]]*tech_debt_file:/ {print $2; exit}' "${map_file}")"

next_num="$(
  rg -o "TD-[0-9]{3}" "${tech_debt_file}" "${map_file}" \
    | sed -E 's/.*TD-([0-9]{3}).*/\1/' \
    | sort -n \
    | tail -n 1
)"
if [ -z "${next_num}" ]; then
  next_num="000"
fi
next_num=$((10#${next_num} + 1))
td_id="$(printf 'TD-%03d' "${next_num}")"

if rg -n "^\\s*-\\s*td_id:\\s*${td_id}$" "${map_file}" >/dev/null; then
  echo "生成 TD ID 冲突：${td_id}" >&2
  exit 1
fi

today="$(wf_now_date)"

tmp_td="$(mktemp)"
awk -v row="| ${td_id} | ${title} | ${impact} | ${priority} | ${acceptance} | Open | ${today} | ${note} |" '
  /^## 已完成/ && inserted == 0 {
    print row
    print ""
    inserted=1
  }
  { print }
' "${tech_debt_file}" > "${tmp_td}"
mv "${tmp_td}" "${tech_debt_file}"

{
  echo ""
  echo "  - td_id: ${td_id}"
  echo "    title: ${title}"
  echo "    cap_id: ${cap_id}"
  echo "    branch_prefix: ${branch_prefix}"
  echo "    trigger_paths: ${trigger_paths}"
  echo "    required_docs: ${required_docs}"
  echo "    acceptance_cmds: ${acceptance_cmds}"
  echo "    close_checks: ${close_checks}"
} >> "${map_file}"

wf_log "新增 TD 成功：${td_id}"
wf_log "已写入清单：${tech_debt_file}"
wf_log "已写入映射：${map_file}"
wf_log "下一步：scripts/workflow/start.sh ${td_id}"

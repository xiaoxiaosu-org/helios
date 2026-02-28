#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"
source "${here}/_lib.sh"

scope="${1:-open}"
map_file="$(wf_map_file)"
tech_debt_file="$(awk -F': ' '/^[[:space:]]*tech_debt_file:/ {print $2; exit}' "${map_file}")"

if [ ! -f "${tech_debt_file}" ]; then
  echo "缺少技术债清单：${tech_debt_file}" >&2
  exit 1
fi

if [ "${scope}" != "open" ] && [ "${scope}" != "done" ] && [ "${scope}" != "all" ]; then
  echo "用法：scripts/workflow/td-list.sh [open|done|all]" >&2
  exit 1
fi

awk -F'|' -v scope="${scope}" '
  function trim(s) {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
    return s
  }
  BEGIN {
    printf "%-8s %-6s %-14s %-8s %-12s %s\n", "TD", "区域", "状态", "优先级", "最近更新", "标题"
    print "-------------------------------------------------------------------------------"
  }
  /^## 在制技术债/ { section="open"; next }
  /^## 已完成/ { section="done"; next }

  section == "open" && /^\| TD-[0-9]{3} / {
    if (scope == "open" || scope == "all") {
      printf "%-8s %-6s %-14s %-8s %-12s %s\n",
        trim($2), "在制", trim($7), trim($5), trim($8), trim($3)
    }
  }
  section == "done" && /^\| TD-[0-9]{3} / {
    if (scope == "done" || scope == "all") {
      printf "%-8s %-6s %-14s %-8s %-12s %s\n",
        trim($2), "完成", "Done", "-", trim($4), trim($3)
    }
  }
' "${tech_debt_file}"

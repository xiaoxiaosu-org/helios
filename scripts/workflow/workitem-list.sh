#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"
source "${here}/_lib.sh"

scope="${1:-all}"
case "${scope}" in
  todo|in_progress|blocked|done|all) ;;
  *)
    echo "用法：scripts/workflow/workitem-list.sh [todo|in_progress|blocked|done|all]" >&2
    exit 1
    ;;
esac

wf_ensure_backlog_exists
backlog_file="$(wf_backlog_file)"

node -e '
const fs = require("node:fs");
const file = process.argv[1];
const scope = process.argv[2];
const data = JSON.parse(fs.readFileSync(file, "utf-8"));
const items = data.workItems || [];
const filtered = items
  .filter((item) => scope === "all" || String(item.status || "") === scope)
  .sort((a, b) => String(a.workItemId || "").localeCompare(String(b.workItemId || "")));

const pad = (text, len) => {
  const s = String(text || "-");
  return s.length >= len ? s.slice(0, len) : s + " ".repeat(len - s.length);
};

console.log(`${pad("WorkItem", 21)} ${pad("Plan", 16)} ${pad("状态", 12)} ${pad("类型", 12)} ${pad("优先级", 8)} 标题`);
console.log("------------------------------------------------------------------------------------------------");
for (const item of filtered) {
  console.log(
    `${pad(item.workItemId, 21)} ${pad(item.planId, 16)} ${pad(item.status, 12)} ${pad(item.kind, 12)} ${pad(item.priority, 8)} ${String(item.title || "-")}`
  );
}
if (filtered.length === 0) {
  console.log("(empty)");
}
' "${backlog_file}" "${scope}"

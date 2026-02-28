#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"
source "${here}/_lib.sh"

usage() {
  cat <<'__USAGE__'
用法：
  scripts/workflow/workitem-add.sh \
    --plan-id PLAN-YYYYMMDD-NN \
    --kind debt|task|capability|initiative \
    --title "标题" \
    --owner "repo-owner" \
    --priority "P1" \
    [--status todo|in_progress|blocked|done] \
    [--acceptance-cmds "cmd1;cmd2"] \
    [--trigger-paths "path1;path2"] \
    [--required-docs "doc1;doc2"] \
    [--close-checks "move_to_done=true,dependencies_done=false,adr_required=false"] \
    [--branch-prefix "feat/topic"] \
    [--depends-on "WI-PLAN2026022701-01;WI-PLAN2026022701-02"]
__USAGE__
}

plan_id=""
kind=""
title=""
owner=""
priority=""
status="todo"
acceptance_cmds=""
trigger_paths=""
required_docs=""
close_checks="move_to_done=true,dependencies_done=false,adr_required=false"
branch_prefix=""
depends_on=""

while [ $# -gt 0 ]; do
  case "$1" in
    --plan-id) plan_id="${2:-}"; shift 2 ;;
    --kind) kind="${2:-}"; shift 2 ;;
    --title) title="${2:-}"; shift 2 ;;
    --owner) owner="${2:-}"; shift 2 ;;
    --priority) priority="${2:-}"; shift 2 ;;
    --status) status="${2:-}"; shift 2 ;;
    --acceptance-cmds) acceptance_cmds="${2:-}"; shift 2 ;;
    --trigger-paths) trigger_paths="${2:-}"; shift 2 ;;
    --required-docs) required_docs="${2:-}"; shift 2 ;;
    --close-checks) close_checks="${2:-}"; shift 2 ;;
    --branch-prefix) branch_prefix="${2:-}"; shift 2 ;;
    --depends-on) depends_on="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 1 ;;
  esac
done

[ -n "${plan_id}" ] || { echo "缺少 --plan-id" >&2; usage; exit 1; }
[ -n "${kind}" ] || { echo "缺少 --kind" >&2; usage; exit 1; }
[ -n "${title}" ] || { echo "缺少 --title" >&2; usage; exit 1; }
[ -n "${owner}" ] || { echo "缺少 --owner" >&2; usage; exit 1; }
[ -n "${priority}" ] || { echo "缺少 --priority" >&2; usage; exit 1; }

if ! echo "${plan_id}" | grep -Eq '^PLAN-[0-9]{8}-[0-9]{2}$'; then
  echo "--plan-id 必须是 PLAN-YYYYMMDD-NN" >&2
  exit 1
fi

case "${kind}" in
  debt|task|capability|initiative) ;;
  *) echo "--kind 必须是 debt|task|capability|initiative" >&2; exit 1 ;;
esac

case "${status}" in
  todo|in_progress|blocked|done) ;;
  *) echo "--status 必须是 todo|in_progress|blocked|done" >&2; exit 1 ;;
esac

if ! echo "${priority}" | grep -Eq '^P[0-9]+$'; then
  echo "--priority 必须为 P0/P1/..." >&2
  exit 1
fi

wf_ensure_backlog_exists
backlog_file="$(wf_backlog_file)"
today="$(wf_now_date)"

node -e '
const fs = require("node:fs");
const file = process.argv[1];
const planId = process.argv[2];
const kind = process.argv[3];
const title = process.argv[4];
const owner = process.argv[5];
const priority = process.argv[6];
const status = process.argv[7];
const acceptanceCmds = process.argv[8];
const triggerPaths = process.argv[9];
const requiredDocs = process.argv[10];
const closeChecks = process.argv[11];
const branchPrefix = process.argv[12];
const dependsOn = process.argv[13];
const today = process.argv[14];

const data = JSON.parse(fs.readFileSync(file, "utf-8"));
const planToken = planId.replace(/-/g, "");
const idPrefix = `WI-${planToken}-`;

const used = (data.workItems || [])
  .filter((item) => String(item.planId || "") === planId)
  .map((item) => String(item.workItemId || ""))
  .filter((id) => id.startsWith(idPrefix))
  .map((id) => Number(id.slice(idPrefix.length)))
  .filter((n) => Number.isInteger(n));

const next = (used.length ? Math.max(...used) : 0) + 1;
const workItemId = `${idPrefix}${String(next).padStart(2, "0")}`;

const split = (input) => String(input || "")
  .split(";")
  .map((x) => x.trim())
  .filter(Boolean);

const item = {
  workItemId,
  planId,
  kind,
  title,
  owner,
  status,
  priority,
  lastUpdate: today,
  detail: {
    note: ""
  },
  links: {
    dependsOnWorkItems: split(dependsOn)
  },
  acceptance: {
    cmds: split(acceptanceCmds),
    evidenceDir: kind === "debt" || kind === "task" ? "artifacts/workflow/" : ""
  },
};

if (kind === "debt" || kind === "task") {
  item.workflow = {
    branchPrefix: branchPrefix || "",
    triggerPaths: split(triggerPaths),
    requiredDocs: split(requiredDocs),
    acceptanceCmds: split(acceptanceCmds),
    closeChecks: closeChecks || "move_to_done=true,dependencies_done=false,adr_required=false",
  };
  item.tracking = {
    eventsFile: `artifacts/workflow/events/${workItemId}.jsonl`,
  };
}

data.workItems = data.workItems || [];
data.workItems.push(item);

fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`, "utf-8");
process.stdout.write(workItemId);
' "${backlog_file}" "${plan_id}" "${kind}" "${title}" "${owner}" "${priority}" "${status}" "${acceptance_cmds}" "${trigger_paths}" "${required_docs}" "${close_checks}" "${branch_prefix}" "${depends_on}" "${today}"

echo
wf_log "新增 WorkItem 成功（请执行 scripts/workflow/backlog.sh build 进行规范化）"

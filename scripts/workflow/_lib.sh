#!/usr/bin/env bash
set -euo pipefail

WF_WORK_ITEM_ID_RE='^WI-PLAN[0-9]{10}-[0-9]{2}$'

wf_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

wf_now_date() {
  date -u +"%Y-%m-%d"
}

wf_now_compact() {
  date -u +"%Y%m%dT%H%M%SZ"
}

wf_log() {
  local prefix="[workflow]"
  if [ "${WF_WORK_ITEM_ID:-}" != "" ]; then
    prefix="[workflow][${WF_WORK_ITEM_ID}]"
  fi
  echo "${prefix}[$(wf_now)] $*"
}

wf_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

wf_backlog_file() {
  echo "docs/02-架构/执行计划/backlog.yaml"
}

wf_ensure_backlog_exists() {
  local file
  file="$(wf_backlog_file)"
  if [ -f "${file}" ]; then
    return 0
  fi
  wf_log "缺少 backlog 主文件：${file}" >&2
  exit 1
}

wf_validate_work_item_id() {
  local work_item_id="$1"
  echo "${work_item_id}" | grep -Eq "${WF_WORK_ITEM_ID_RE}"
}

wf_work_item_exists() {
  local work_item_id="$1"
  local backlog_file
  backlog_file="$(wf_backlog_file)"

  node -e '
const fs = require("node:fs");
const backlogFile = process.argv[1];
const workItemId = process.argv[2];
const data = JSON.parse(fs.readFileSync(backlogFile, "utf-8"));
const found = (data.workItems || []).some((item) => String(item.workItemId || "") === workItemId);
process.exit(found ? 0 : 1);
' "${backlog_file}" "${work_item_id}" 2>/dev/null
}

wf_resolve_work_item_id() {
  local input_id="$1"
  wf_validate_work_item_id "${input_id}" || return 1
  wf_work_item_exists "${input_id}" || return 1
  echo "${input_id}"
}

wf_get_field() {
  local work_item_id="$1"
  local field="$2"
  local backlog_file
  backlog_file="$(wf_backlog_file)"

  node -e '
const fs = require("node:fs");
const backlogFile = process.argv[1];
const workItemId = process.argv[2];
const field = process.argv[3];
const data = JSON.parse(fs.readFileSync(backlogFile, "utf-8"));
const item = (data.workItems || []).find((it) => String(it.workItemId || "") === workItemId);
if (!item) process.exit(1);

const workflow = item.workflow || {};
const acceptance = item.acceptance || {};
const links = item.links || {};
let value = "";

switch (field) {
  case "plan_id":
    value = item.planId || "";
    break;
  case "kind":
    value = item.kind || "";
    break;
  case "title":
    value = item.title || "";
    break;
  case "status":
    value = item.status || "";
    break;
  case "priority":
    value = item.priority || "";
    break;
  case "owner":
    value = item.owner || "";
    break;
  case "branch_prefix":
    value = workflow.branchPrefix || "";
    break;
  case "trigger_paths":
    value = (workflow.triggerPaths || []).join(";");
    break;
  case "required_docs":
    value = (workflow.requiredDocs || []).join(";");
    break;
  case "acceptance_cmds":
    value = (workflow.acceptanceCmds || acceptance.cmds || []).join(";");
    break;
  case "close_checks":
    value = workflow.closeChecks || "";
    break;
  case "depends_on":
    value = (links.dependsOnWorkItems || []).join(";");
    break;
  case "events_file":
    value = ((item.tracking || {}).eventsFile || "");
    break;
  default:
    process.exit(1);
}

if (!value) process.exit(1);
process.stdout.write(String(value));
' "${backlog_file}" "${work_item_id}" "${field}" 2>/dev/null
}

wf_split_semicolon() {
  local _input="$1"
  IFS=';' read -r -a WF_ITEMS <<< "${_input}"
}

wf_artifact_dir() {
  local work_item_id="$1"
  local run_id
  run_id="$(wf_now_compact)-$(git rev-parse --short HEAD 2>/dev/null || echo nogit)"
  local out_dir="artifacts/workflow/${work_item_id}/${run_id}"
  mkdir -p "${out_dir}"
  echo "${out_dir}"
}

wf_update_work_item_status() {
  local work_item_id="$1"
  local new_status="$2"
  local new_date="$3"
  local note_suffix="${4:-}"
  local backlog_file
  backlog_file="$(wf_backlog_file)"

  node -e '
const fs = require("node:fs");
const file = process.argv[1];
const workItemId = process.argv[2];
const newStatus = process.argv[3];
const newDate = process.argv[4];
const note = process.argv[5];

const data = JSON.parse(fs.readFileSync(file, "utf-8"));
const item = (data.workItems || []).find((it) => String(it.workItemId || "") === workItemId);
if (!item) {
  process.stderr.write(`workItem 不存在: ${workItemId}\n`);
  process.exit(1);
}
item.status = newStatus;
item.lastUpdate = newDate;
if (note) {
  const detail = item.detail && typeof item.detail === "object" ? item.detail : {};
  const previous = String(detail.note || "").trim();
  detail.note = previous ? `${previous}；${note}` : note;
  item.detail = detail;
}
fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`, "utf-8");
' "${backlog_file}" "${work_item_id}" "${new_status}" "${new_date}" "${note_suffix}"
}

wf_get_close_check_flag() {
  local close_checks="$1"
  local key="$2"
  local value
  value="$(echo "${close_checks}" | tr ',' '\n' | awk -F'=' -v key="${key}" '$1 ~ key {print $2; exit}')"
  if [ -z "${value}" ]; then
    echo "false"
    return
  fi
  echo "${value}"
}

wf_has_adr_for_work_item() {
  local work_item_id="$1"
  local backlog_file
  backlog_file="$(wf_backlog_file)"
  local adr_index_file

  adr_index_file="$(node -e '
const fs = require("node:fs");
const file = process.argv[1];
const data = JSON.parse(fs.readFileSync(file, "utf-8"));
const v = (((data || {}).sources || {}).adrIndexFile || "").trim();
if (!v) process.exit(1);
process.stdout.write(v);
' "${backlog_file}" 2>/dev/null || true)"

  [ -n "${adr_index_file}" ] || return 1
  [ -f "${adr_index_file}" ] || return 1

  local token
  token="$(echo "${work_item_id}" | tr '[:upper:]' '[:lower:]')"
  grep -Ei "${token}" "${adr_index_file}" >/dev/null
}

wf_all_dependencies_done() {
  local work_item_id="$1"
  local backlog_file
  backlog_file="$(wf_backlog_file)"
  local dep
  local rc

  set +e
  dep="$(node -e '
const fs = require("node:fs");
const file = process.argv[1];
const workItemId = process.argv[2];
const data = JSON.parse(fs.readFileSync(file, "utf-8"));
const items = data.workItems || [];
const me = items.find((it) => String(it.workItemId || "") === workItemId);
if (!me) process.exit(1);
const deps = ((me.links || {}).dependsOnWorkItems || []).map(String);
for (const targetId of deps) {
  const target = items.find((it) => String(it.workItemId || "") === targetId);
  if (!target || String(target.status || "") !== "done") {
    process.stdout.write(targetId);
    process.exit(2);
  }
}
process.exit(0);
' "${backlog_file}" "${work_item_id}" 2>/dev/null)"
  rc=$?
  set -e

  if [ "${rc}" -eq 1 ]; then
    return 1
  fi

  if [ -n "${dep}" ]; then
    echo "${dep}"
    return 1
  fi
  return 0
}

wf_append_event() {
  local work_item_id="$1"
  local event_type="$2"
  local status="$3"
  local message="${4:-}"
  local extra_json="${5:-{}}"
  local ts
  ts="$(wf_now)"
  local actor
  actor="${USER:-unknown}"

  local events_file
  events_file="$(wf_get_field "${work_item_id}" events_file || true)"
  if [ -z "${events_file}" ]; then
    events_file="artifacts/workflow/events/${work_item_id}.jsonl"
  fi

  mkdir -p "$(dirname "${events_file}")"

  local payload_line
  payload_line="$(node -e '
const workItemId = process.argv[1];
const eventType = process.argv[2];
const status = process.argv[3];
const message = process.argv[4];
const ts = process.argv[5];
const actor = process.argv[6];
const extraRaw = process.argv[7];
let extra = {};
if (extraRaw) {
  try {
    extra = JSON.parse(extraRaw);
  } catch {
    extra = { raw: extraRaw };
  }
}
const payload = {
  timestamp: ts,
  workItemId,
  eventType,
  status,
  message,
  actor,
  ...extra,
};
process.stdout.write(JSON.stringify(payload));
' "${work_item_id}" "${event_type}" "${status}" "${message}" "${ts}" "${actor}" "${extra_json}" 2>/dev/null || true)"

  [ -n "${payload_line}" ] || return 0
  printf '%s\n' "${payload_line}" >> "${events_file}"

  if [ -n "${WF_RUN_DIR:-}" ]; then
    mkdir -p "${WF_RUN_DIR}"
    printf '%s\n' "${payload_line}" >> "${WF_RUN_DIR}/events.jsonl"
  fi
}

wf_help() {
  cat <<'__WF_HELP__'
用法：
  scripts/workflow/start.sh WI-PLANYYYYMMDDNN-01
  scripts/workflow/progress.sh WI-PLANYYYYMMDDNN-01
  scripts/workflow/close.sh WI-PLANYYYYMMDDNN-01
  scripts/workflow/workitem-list.sh [todo|in_progress|blocked|done|all]
  scripts/workflow/workitem-add.sh --plan-id PLAN-YYYYMMDD-NN --kind debt|task|capability --title ... --owner ... --priority P1
__WF_HELP__
}

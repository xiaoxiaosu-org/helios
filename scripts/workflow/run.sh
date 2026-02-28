#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

cmd="${1:-}"
if [ -z "${cmd}" ]; then
  echo "用法：" >&2
  echo "  scripts/workflow/run.sh WI-PLANYYYYMMDDNN-01 [start|progress|close|full]" >&2
  echo "  scripts/workflow/run.sh list [todo|in_progress|blocked|done|all]" >&2
  echo "  scripts/workflow/run.sh plan-add --title ... [--owner ...]" >&2
  echo "  scripts/workflow/run.sh add --plan-id PLAN-YYYYMMDD-NN --kind debt|task|capability --title ... --owner ... --priority P1" >&2
  echo "  scripts/workflow/run.sh overview [json [out_file]|serve [host] [port]]" >&2
  echo "  scripts/workflow/run.sh backlog [build|check]" >&2
  exit 1
fi

if [ "${cmd}" = "list" ]; then
  scope="${2:-all}"
  "${here}/workitem-list.sh" "${scope}"
  exit 0
fi

if [ "${cmd}" = "add" ]; then
  shift
  "${here}/workitem-add.sh" "$@"
  "${here}/backlog.sh" build
  exit 0
fi

if [ "${cmd}" = "plan-add" ]; then
  shift
  "${here}/plan-add.sh" "$@"
  exit 0
fi

if [ "${cmd}" = "overview" ]; then
  shift
  "${here}/overview.sh" "$@"
  exit 0
fi

if [ "${cmd}" = "backlog" ]; then
  shift
  "${here}/backlog.sh" "$@"
  exit 0
fi

work_item_id="${cmd}"
phase="${2:-full}"

case "${phase}" in
  start)
    "${here}/start.sh" "${work_item_id}"
    "${here}/backlog.sh" build
    ;;
  progress)
    "${here}/progress.sh" "${work_item_id}"
    "${here}/backlog.sh" build
    ;;
  close)
    "${here}/close.sh" "${work_item_id}"
    "${here}/backlog.sh" build
    ;;
  full)
    "${here}/start.sh" "${work_item_id}"
    "${here}/progress.sh" "${work_item_id}"
    "${here}/close.sh" "${work_item_id}"
    "${here}/backlog.sh" build
    ;;
  *)
    echo "未知阶段：${phase}，可选 start|progress|close|full" >&2
    exit 1
    ;;
esac

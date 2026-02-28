#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

cmd="${1:-}"
if [ -z "${cmd}" ]; then
  echo "用法：" >&2
  echo "  scripts/workflow/run.sh TD-001 [start|progress|close|full]" >&2
  echo "  scripts/workflow/run.sh list [open|done|all]" >&2
  echo "  scripts/workflow/run.sh add --title ... --impact ... --priority ... --acceptance ... --cap CAP-XXX" >&2
  exit 1
fi

if [ "${cmd}" = "list" ]; then
  scope="${2:-open}"
  "${here}/td-list.sh" "${scope}"
  exit 0
fi

if [ "${cmd}" = "add" ]; then
  shift
  "${here}/td-add.sh" "$@"
  exit 0
fi

td_id="${cmd}"
phase="${2:-full}"

case "${phase}" in
  start)
    "${here}/start.sh" "${td_id}"
    ;;
  progress)
    "${here}/progress.sh" "${td_id}"
    ;;
  close)
    "${here}/close.sh" "${td_id}"
    ;;
  full)
    "${here}/start.sh" "${td_id}"
    "${here}/progress.sh" "${td_id}"
    "${here}/close.sh" "${td_id}"
    ;;
  *)
    echo "未知阶段：${phase}，可选 start|progress|close|full" >&2
    exit 1
    ;;
esac

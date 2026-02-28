#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

td_id="${1:-}"
phase="${2:-full}"

if [ -z "${td_id}" ]; then
  echo "用法：scripts/workflow/run.sh TD-001 [start|progress|close|full]" >&2
  exit 1
fi

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

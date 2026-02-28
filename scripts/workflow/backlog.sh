#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"

cmd="${1:-build}"

case "${cmd}" in
  build|check)
    "${here}/backlog-sync.mjs" "${cmd}"
    ;;
  *)
    echo "用法：" >&2
    echo "  scripts/workflow/backlog.sh [build|check]" >&2
    exit 1
    ;;
esac

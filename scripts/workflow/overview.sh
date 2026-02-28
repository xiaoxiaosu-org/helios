#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"

mode="${1:-json}"
shift || true

case "${mode}" in
  json)
    out_file="${1:-artifacts/workflow/system-overview/latest.json}"
    "${here}/backlog.sh" build
    mkdir -p "$(dirname "${out_file}")"
    "${here}/overview.mjs" json --out "${out_file}"
    echo "[overview] JSON 已输出：${out_file}"
    ;;
  serve)
    host="${1:-127.0.0.1}"
    port="${2:-8787}"
    "${here}/backlog.sh" build
    echo "[overview] 启动本地看板服务：http://${host}:${port}"
    "${here}/overview.mjs" serve --host "${host}" --port "${port}"
    ;;
  *)
    echo "用法：" >&2
    echo "  scripts/workflow/overview.sh json [out_file]" >&2
    echo "  scripts/workflow/overview.sh serve [host] [port]" >&2
    exit 1
    ;;
esac

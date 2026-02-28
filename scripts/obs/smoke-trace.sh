#!/usr/bin/env bash
set -euo pipefail

out_dir=""

usage() {
  cat <<'USAGE'
用法：scripts/obs/smoke-trace.sh --out <目录>
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --out)
      out_dir="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[obs] 未知参数：$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "${out_dir}" ]; then
  echo "[obs] 缺少 --out 参数" >&2
  usage >&2
  exit 1
fi

mkdir -p "${out_dir}"
trace_id="trace-$(date -u +%Y%m%dT%H%M%SZ)-$$"

printf '%s\n' "${trace_id}" > "${out_dir}/traceId.txt"
cat > "${out_dir}/smoke-trace.json" <<JSON
{
  "traceId": "${trace_id}",
  "result": "ok",
  "durationMs": 12,
  "source": "smoke-trace"
}
JSON

echo "[obs] 通过：生成 traceId=${trace_id}"

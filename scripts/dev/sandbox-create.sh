#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "用法：scripts/dev/sandbox-create.sh [--smoke] [--out <dir>]" >&2
  exit 1
}

smoke_mode=0
out_dir=""

while [ $# -gt 0 ]; do
  case "$1" in
    --smoke)
      smoke_mode=1
      shift
      ;;
    --out)
      out_dir="${2:-}"
      [ -n "${out_dir}" ] || usage
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [ -z "${out_dir}" ]; then
  out_dir="${ARTIFACT_DIR:-artifacts/cap/CAP-001}"
fi

mkdir -p "${out_dir}"

sandbox_id="sbx-$(date -u +%Y%m%dT%H%M%SZ)-$$"
sandbox_root="/tmp/helios-sandbox-${sandbox_id}"
mkdir -p "${sandbox_root}"

{
  echo "SANDBOX_ID=${sandbox_id}"
  echo "SANDBOX_ROOT=${sandbox_root}"
  if [ "${smoke_mode}" -eq 1 ]; then
    echo "SANDBOX_MODE=smoke"
  else
    echo "SANDBOX_MODE=normal"
  fi
} > "${out_dir}/sandbox.env"

echo "[sandbox-create] 已创建：${sandbox_root}"
echo "[sandbox-create] 环境文件：${out_dir}/sandbox.env"

#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "用法：scripts/dev/sandbox-destroy.sh [--smoke] [--out <dir>]" >&2
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

env_file="${out_dir}/sandbox.env"
cleanup_log="${out_dir}/cleanup.log"
mkdir -p "${out_dir}"

if [ ! -f "${env_file}" ]; then
  {
    echo "[sandbox-destroy] 未找到环境文件：${env_file}"
    echo "[sandbox-destroy] 无清理动作。"
  } > "${cleanup_log}"
  exit 0
fi

# shellcheck disable=SC1090
source "${env_file}"

sandbox_root="${SANDBOX_ROOT:-}"
if [ -z "${sandbox_root}" ]; then
  {
    echo "[sandbox-destroy] SANDBOX_ROOT 为空，跳过清理。"
  } > "${cleanup_log}"
  exit 0
fi

if ! echo "${sandbox_root}" | grep -Eq '^/tmp/helios-sandbox-'; then
  {
    echo "[sandbox-destroy] 非法路径，拒绝删除：${sandbox_root}"
  } > "${cleanup_log}"
  exit 1
fi

if [ -d "${sandbox_root}" ]; then
  rm -rf "${sandbox_root}"
  cleaned="yes"
else
  cleaned="no"
fi

{
  echo "sandboxRoot=${sandbox_root}"
  echo "removed=${cleaned}"
  if [ "${smoke_mode}" -eq 1 ]; then
    echo "mode=smoke"
  else
    echo "mode=normal"
  fi
  echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "${cleanup_log}"

echo "[sandbox-destroy] 清理完成：${sandbox_root} (removed=${cleaned})"
echo "[sandbox-destroy] 清理日志：${cleanup_log}"

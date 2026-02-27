#!/usr/bin/env bash
set -euo pipefail

cap_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

cap_log() {
  local prefix="[cap]"
  if [ "${CAP_ID:-}" != "" ]; then
    prefix="[cap][${CAP_ID}]"
  fi
  echo "${prefix}[$(cap_now)] $*"
}

cap_now_utc() {
  date -u +"%Y%m%dT%H%M%SZ"
}

cap_git_sha() {
  git rev-parse --short HEAD 2>/dev/null || echo "nogit"
}

cap_mkdir_run_dir() {
  local cap_id="$1"
  local base_dir="${ARTIFACTS_DIR:-artifacts}"
  local run_id
  run_id="$(cap_now_utc)-$(cap_git_sha)"
  local run_dir="${base_dir}/${cap_id}/${run_id}"
  mkdir -p "${run_dir}"
  echo "${run_dir}"
}

cap_write_meta() {
  local run_dir="$1"
  local cap_id="$2"
  local command_str="$3"
  local exit_code="$4"
  local status="$5"

  local run_id
  run_id="$(basename "$run_dir")"

  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  local sha
  sha="$(git rev-parse HEAD 2>/dev/null || echo "nogit")"

  cat > "${run_dir}/meta.json" <<JSON
{
  "capId": "${cap_id}",
  "runId": "${run_id}",
  "timestamp": "${ts}",
  "gitSha": "${sha}",
  "command": "${command_str}",
  "exitCode": ${exit_code},
  "status": "${status}"
}
JSON
}

cap_status_from_exit_code() {
  local exit_code="$1"
  case "${exit_code}" in
    0) echo "pass" ;;
    1) echo "fail" ;;
    2) echo "blocked" ;;
    *) echo "error" ;;
  esac
}

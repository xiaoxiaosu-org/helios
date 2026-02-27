#!/usr/bin/env bash
set -euo pipefail

ci_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log() {
  echo "[ci][$(ci_now)] $*"
}

ci_begin() {
  CI_GATE_NAME="${1:-$(basename "$0")}"
  CI_GATE_START_S="$(date +%s)"
  log "启动：${CI_GATE_NAME}"

  trap 'ci_on_exit "$?"' EXIT
}

ci_on_exit() {
  local exit_code="$1"
  local end_s
  end_s="$(date +%s)"
  local duration_s
  duration_s="$(( end_s - ${CI_GATE_START_S:-end_s} ))"

  if [ "${exit_code}" -eq 0 ]; then
    log "结束：成功（耗时 ${duration_s}s）"
  else
    log "结束：失败（退出码 ${exit_code}，耗时 ${duration_s}s）"
  fi
}

ci_run() {
  log "执行：$*"
  "$@"
}

has_file() {
  [ -f "$1" ]
}

has_any_code_dir() {
  [ -d modules ] || [ -d apps ] || [ -d services ] || [ -d src ]
}

has_npm_script() {
  local script_name="$1"
  if ! [ -f package.json ]; then
    return 1
  fi
  if ! command -v node >/dev/null 2>&1; then
    return 1
  fi
  node -e "const p=require('./package.json'); process.exit((p.scripts&&p.scripts['${script_name}'])?0:1)" 2>/dev/null
}

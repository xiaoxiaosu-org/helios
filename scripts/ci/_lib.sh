#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[ci] $*"
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

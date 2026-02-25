#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

log "typecheck gate start"

if has_file package.json && command -v npm >/dev/null 2>&1; then
  if has_npm_script typecheck; then
    log "running npm run typecheck"
    npm run typecheck
    exit 0
  fi
  if [ -f tsconfig.json ] && command -v npx >/dev/null 2>&1; then
    log "running npx tsc --noEmit (fallback)"
    npx tsc --noEmit
    exit 0
  fi
fi

if has_file pyproject.toml && command -v mypy >/dev/null 2>&1; then
  log "running mypy ."
  mypy .
  exit 0
fi

if has_file pom.xml || has_file build.gradle || has_file build.gradle.kts; then
  log "JVM project detected; typecheck is covered by build/test pipeline, please customize if needed"
  exit 0
fi

if has_any_code_dir; then
  log "no typecheck command detected; customize scripts/ci/typecheck.sh for this repository"
  exit 1
fi

log "no business code stack detected, skip typecheck"

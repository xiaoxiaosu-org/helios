#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

log "build gate start"

if has_file package.json && command -v npm >/dev/null 2>&1; then
  if node -e 'const p=require("./package.json"); process.exit(!(p.scripts&&p.scripts.build));' 2>/dev/null; then
    log "running npm run build"
    npm run build
    exit 0
  fi
fi

if has_file pyproject.toml; then
  if command -v python >/dev/null 2>&1; then
    log "python project detected; no default build command configured, customize if packaging is required"
    exit 0
  fi
fi

if has_file pom.xml && [ -x ./mvnw ]; then
  log "running ./mvnw -B -DskipTests package"
  ./mvnw -B -DskipTests package
  exit 0
fi

if (has_file build.gradle || has_file build.gradle.kts) && [ -x ./gradlew ]; then
  log "running ./gradlew build -x test"
  ./gradlew build -x test
  exit 0
fi

if has_any_code_dir; then
  log "no build command detected; customize scripts/ci/build.sh for this repository"
  exit 1
fi

log "no business code stack detected, skip build"

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

log "lint gate start"

if has_file package.json && command -v npm >/dev/null 2>&1; then
  if has_npm_script lint; then
    log "running npm run lint"
    npm run lint
    exit 0
  fi
fi

if has_file pyproject.toml || has_file requirements.txt; then
  if command -v ruff >/dev/null 2>&1; then
    log "running ruff check ."
    ruff check .
    exit 0
  fi
fi

if has_file pom.xml || has_file build.gradle || has_file build.gradle.kts; then
  if [ -x ./mvnw ]; then
    if grep -qi "spotless" pom.xml 2>/dev/null; then
      log "running ./mvnw -B spotless:check"
      ./mvnw -B spotless:check
      exit 0
    fi
    if grep -qi "checkstyle" pom.xml 2>/dev/null; then
      log "running ./mvnw -B checkstyle:check"
      ./mvnw -B checkstyle:check
      exit 0
    fi
    log "maven project detected but no spotless/checkstyle plugin found; customize scripts/ci/lint.sh"
    exit 1
  fi
  if [ -x ./gradlew ]; then
    if grep -qi "spotless" build.gradle build.gradle.kts 2>/dev/null; then
      log "running ./gradlew spotlessCheck"
      ./gradlew spotlessCheck
      exit 0
    fi
    if grep -qi "checkstyle" build.gradle build.gradle.kts 2>/dev/null; then
      log "running ./gradlew checkstyleMain"
      ./gradlew checkstyleMain
      exit 0
    fi
    log "gradle project detected but no spotless/checkstyle plugin found; customize scripts/ci/lint.sh"
    exit 1
  fi
fi

if has_any_code_dir; then
  log "no lint command detected; customize scripts/ci/lint.sh for this repository"
  exit 1
fi

log "no business code stack detected, skip lint"

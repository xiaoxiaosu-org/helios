#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

log "test gate start"

if has_file package.json && command -v npm >/dev/null 2>&1; then
  if has_npm_script test:ci; then
    log "running npm run test:ci"
    npm run test:ci
    exit 0
  fi
  if has_npm_script test:coverage; then
    log "running npm run test:coverage"
    npm run test:coverage
    exit 0
  fi
  if has_npm_script test; then
    log "running npm test"
    npm test
    exit 0
  fi
fi

if has_file pyproject.toml || has_file requirements.txt; then
  if command -v pytest >/dev/null 2>&1; then
    log "running pytest"
    pytest
    exit 0
  fi
fi

if has_file pom.xml && [ -x ./mvnw ]; then
  if grep -qi "jacoco" pom.xml 2>/dev/null; then
    log "running ./mvnw -B test jacoco:report"
    ./mvnw -B test jacoco:report
  else
    log "running ./mvnw -B test"
    ./mvnw -B test
  fi
  exit 0
fi

if (has_file build.gradle || has_file build.gradle.kts) && [ -x ./gradlew ]; then
  if grep -qi "jacoco" build.gradle build.gradle.kts 2>/dev/null; then
    log "running ./gradlew test jacocoTestReport"
    ./gradlew test jacocoTestReport
  else
    log "running ./gradlew test"
    ./gradlew test
  fi
  exit 0
fi

if has_any_code_dir; then
  log "no test command detected; customize scripts/ci/test.sh for this repository"
  exit 1
fi

log "no business code stack detected, skip test"

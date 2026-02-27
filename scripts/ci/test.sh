#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

ci_begin "测试门禁"

if has_file package.json && command -v npm >/dev/null 2>&1; then
  if has_npm_script test:ci; then
    ci_run npm run test:ci
    exit 0
  fi
  if has_npm_script test:coverage; then
    ci_run npm run test:coverage
    exit 0
  fi
  if has_npm_script test; then
    ci_run npm test
    exit 0
  fi
fi

if has_file pyproject.toml || has_file requirements.txt; then
  if command -v pytest >/dev/null 2>&1; then
    ci_run pytest
    exit 0
  fi
fi

if has_file pom.xml && [ -x ./mvnw ]; then
  if grep -qi "jacoco" pom.xml 2>/dev/null; then
    ci_run ./mvnw -B test jacoco:report
  else
    ci_run ./mvnw -B test
  fi
  exit 0
fi

if (has_file build.gradle || has_file build.gradle.kts) && [ -x ./gradlew ]; then
  if grep -qi "jacoco" build.gradle build.gradle.kts 2>/dev/null; then
    ci_run ./gradlew test jacocoTestReport
  else
    ci_run ./gradlew test
  fi
  exit 0
fi

if has_any_code_dir; then
  log "检测到业务代码目录，但未识别可用的测试命令。请完善 scripts/ci/test.sh"
  exit 1
fi

log "未检测到业务代码栈，跳过测试"

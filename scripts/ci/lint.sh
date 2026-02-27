#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

ci_begin "Lint 门禁"

if has_file package.json && command -v npm >/dev/null 2>&1; then
  if has_npm_script lint; then
    ci_run npm run lint
    exit 0
  fi
fi

if has_file pyproject.toml || has_file requirements.txt; then
  if command -v ruff >/dev/null 2>&1; then
    ci_run ruff check .
    exit 0
  fi
fi

if has_file pom.xml || has_file build.gradle || has_file build.gradle.kts; then
  if [ -x ./mvnw ]; then
    if grep -qi "spotless" pom.xml 2>/dev/null; then
      ci_run ./mvnw -B spotless:check
      exit 0
    fi
    if grep -qi "checkstyle" pom.xml 2>/dev/null; then
      ci_run ./mvnw -B checkstyle:check
      exit 0
    fi
    log "检测到 Maven 项目，但未发现 spotless/checkstyle 插件。请按项目实际情况完善 scripts/ci/lint.sh"
    exit 1
  fi
  if [ -x ./gradlew ]; then
    if grep -qi "spotless" build.gradle build.gradle.kts 2>/dev/null; then
      ci_run ./gradlew spotlessCheck
      exit 0
    fi
    if grep -qi "checkstyle" build.gradle build.gradle.kts 2>/dev/null; then
      ci_run ./gradlew checkstyleMain
      exit 0
    fi
    log "检测到 Gradle 项目，但未发现 spotless/checkstyle 插件。请按项目实际情况完善 scripts/ci/lint.sh"
    exit 1
  fi
fi

if has_any_code_dir; then
  log "检测到业务代码目录，但未识别可用的 lint 命令。请完善 scripts/ci/lint.sh"
  exit 1
fi

log "未检测到业务代码栈，跳过 lint"

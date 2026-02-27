#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

ci_begin "类型检查门禁"

if has_file package.json && command -v npm >/dev/null 2>&1; then
  if has_npm_script typecheck; then
    ci_run npm run typecheck
    exit 0
  fi
  if [ -f tsconfig.json ] && command -v npx >/dev/null 2>&1; then
    ci_run npx tsc --noEmit
    exit 0
  fi
fi

if has_file pyproject.toml && command -v mypy >/dev/null 2>&1; then
  ci_run mypy .
  exit 0
fi

if has_file pom.xml || has_file build.gradle || has_file build.gradle.kts; then
  log "检测到 JVM 项目：默认认为类型检查由 build/test 覆盖；如需单独门禁请完善 scripts/ci/typecheck.sh"
  exit 0
fi

if has_any_code_dir; then
  log "检测到业务代码目录，但未识别可用的类型检查命令。请完善 scripts/ci/typecheck.sh"
  exit 1
fi

log "未检测到业务代码栈，跳过类型检查"

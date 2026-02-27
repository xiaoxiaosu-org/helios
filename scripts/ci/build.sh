#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

ci_begin "构建门禁"

if has_file package.json && command -v npm >/dev/null 2>&1; then
  if node -e 'const p=require("./package.json"); process.exit(!(p.scripts&&p.scripts.build));' 2>/dev/null; then
    ci_run npm run build
    exit 0
  fi
fi

if has_file pyproject.toml; then
  if command -v python >/dev/null 2>&1; then
    log "检测到 Python 项目：默认无构建命令（如需打包/发布请完善 scripts/ci/build.sh）"
    exit 0
  fi
fi

if has_file pom.xml && [ -x ./mvnw ]; then
  ci_run ./mvnw -B -DskipTests package
  exit 0
fi

if (has_file build.gradle || has_file build.gradle.kts) && [ -x ./gradlew ]; then
  ci_run ./gradlew build -x test
  exit 0
fi

if has_any_code_dir; then
  log "检测到业务代码目录，但未识别可用的构建命令。请完善 scripts/ci/build.sh"
  exit 1
fi

log "未检测到业务代码栈，跳过构建"

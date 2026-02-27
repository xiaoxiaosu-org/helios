#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/dev/bootstrap-governance-baseline.sh [options]

Options:
  --target <dir>            Target project directory (default: current directory)
  --force                   Overwrite managed files when content differs
  --dry-run                 Preview changes without writing files
  --skip-init-git           Do not run git init when .git is missing
  --skip-verify             Do not run install-hooks/index-check/verify after scaffold
  --setup-global-git        Configure recommended global git options
  --git-user-name <name>    Used with --setup-global-git
  --git-user-email <email>  Used with --setup-global-git
  -h, --help                Show this help

Examples:
  scripts/dev/bootstrap-governance-baseline.sh --target /tmp/new-project
  scripts/dev/bootstrap-governance-baseline.sh --target . --dry-run
  scripts/dev/bootstrap-governance-baseline.sh --target . --force
EOF
}

log() {
  echo "[bootstrap] $*"
}

fail() {
  echo "[bootstrap] ERROR: $*" >&2
  exit 1
}

target="."
force=0
dry_run=0
init_git=1
run_verify=1
setup_global_git=0
git_user_name=""
git_user_email=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)
      [ "$#" -ge 2 ] || fail "--target requires a value"
      target="$2"
      shift 2
      ;;
    --force)
      force=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --skip-init-git)
      init_git=0
      shift
      ;;
    --skip-verify)
      run_verify=0
      shift
      ;;
    --setup-global-git)
      setup_global_git=1
      shift
      ;;
    --git-user-name)
      [ "$#" -ge 2 ] || fail "--git-user-name requires a value"
      git_user_name="$2"
      shift 2
      ;;
    --git-user-email)
      [ "$#" -ge 2 ] || fail "--git-user-email requires a value"
      git_user_email="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

if [ "$setup_global_git" -eq 1 ]; then
  [ -n "$git_user_name" ] || fail "--setup-global-git requires --git-user-name"
  [ -n "$git_user_email" ] || fail "--setup-global-git requires --git-user-email"
fi

target="$(cd "$target" 2>/dev/null && pwd || true)"
if [ -z "$target" ]; then
  fail "target directory does not exist"
fi

created=0
updated=0
unchanged=0
conflicts=0
dirs_created=0

ensure_dir() {
  local abs_dir="$1"
  if [ -d "$abs_dir" ]; then
    return 0
  fi
  if [ "$dry_run" -eq 1 ]; then
    log "create dir: ${abs_dir}"
    dirs_created=$((dirs_created + 1))
    return 0
  fi
  mkdir -p "$abs_dir"
  log "created dir: ${abs_dir}"
  dirs_created=$((dirs_created + 1))
}

write_file() {
  local rel="$1"
  local abs="${target}/${rel}"
  local abs_dir
  local tmp
  abs_dir="$(dirname "$abs")"
  ensure_dir "$abs_dir"
  tmp="$(mktemp)"
  cat >"$tmp"

  if [ -f "$abs" ]; then
    if cmp -s "$tmp" "$abs"; then
      unchanged=$((unchanged + 1))
      log "unchanged: ${rel}"
      rm -f "$tmp"
      return 0
    fi

    if [ "$force" -eq 1 ]; then
      if [ "$dry_run" -eq 1 ]; then
        log "update: ${rel}"
      else
        cp "$tmp" "$abs"
        log "updated: ${rel}"
      fi
      updated=$((updated + 1))
      rm -f "$tmp"
      return 0
    fi

    conflicts=$((conflicts + 1))
    log "conflict(skip): ${rel} (use --force to overwrite)"
    rm -f "$tmp"
    return 0
  fi

  if [ "$dry_run" -eq 1 ]; then
    log "create file: ${rel}"
  else
    cp "$tmp" "$abs"
    log "created file: ${rel}"
  fi
  created=$((created + 1))
  rm -f "$tmp"
}

mark_executable() {
  local rel="$1"
  local abs="${target}/${rel}"
  if [ ! -f "$abs" ]; then
    return 0
  fi
  if [ "$dry_run" -eq 1 ]; then
    log "chmod +x ${rel}"
  else
    chmod +x "$abs"
  fi
}

run_in_target() {
  local cmd="$1"
  if [ "$dry_run" -eq 1 ]; then
    log "run: (cd ${target} && ${cmd})"
    return 0
  fi
  (cd "$target" && eval "$cmd")
}

log "target: ${target}"
log "mode: force=${force}, dry_run=${dry_run}, init_git=${init_git}, run_verify=${run_verify}"

# Directory skeleton.
for rel in \
  "docs/00-术语表" \
  "docs/01-产品" \
  "docs/02-架构" \
  "docs/03-领域模型" \
  "docs/04-接口" \
  "docs/05-事件" \
  "docs/06-数据" \
  "docs/07-运行态" \
  "docs/08-安全" \
  "docs/09-ADR-架构决策" \
  "docs/02-架构/工程治理" \
  "docs/02-架构/执行计划" \
  "scripts/ci" \
  "scripts/docs" \
  "scripts/dev" \
  ".githooks" \
  ".github/workflows" \
  ".github"; do
  ensure_dir "${target}/${rel}"
done

# Core entry files.
write_file "AGENTS.md" <<'EOF'
# 项目入口（最小版）
- 文档导航：docs/README.md
- 本地门禁：scripts/ci/verify.sh
- 关键约束：代码/配置/SQL 变更必须同步更新 docs/
EOF

write_file "README.md" <<'EOF'
# Project
- 入口：AGENTS.md
- 文档导航：docs/README.md
- 本地门禁：scripts/ci/verify.sh
EOF

write_file ".github/commit_message_template.md" <<'EOF'
feat(scope): 简要说明

功能:
- 本次功能点

功能与文件映射:
- 功能A: path/a path/b

涉及文件:
- path/a
- path/b

主要改动:
- 关键改动说明

为什么改:
- 背景与目标

验证:
- 执行命令与结果
EOF

write_file ".github/CODEOWNERS" <<'EOF'
* @your-org/your-team
EOF

write_file "docs/README.md" <<'EOF'
# 文档导航
- 术语：docs/00-术语表/README.md
- 产品：docs/01-产品/README.md
- 架构：docs/02-架构/README.md
- 领域：docs/03-领域模型/README.md
- 接口：docs/04-接口/README.md
- 事件：docs/05-事件/README.md
- 数据：docs/06-数据/README.md
- 运行态：docs/07-运行态/README.md
- 安全：docs/08-安全/README.md
- ADR：docs/09-ADR-架构决策/README.md
EOF

# Top-level docs indexes.
for rel in \
  "docs/00-术语表/README.md" \
  "docs/01-产品/README.md" \
  "docs/02-架构/README.md" \
  "docs/03-领域模型/README.md" \
  "docs/04-接口/README.md" \
  "docs/05-事件/README.md" \
  "docs/06-数据/README.md" \
  "docs/07-运行态/README.md" \
  "docs/08-安全/README.md" \
  "docs/09-ADR-架构决策/README.md"; do
  title="$(basename "$(dirname "$rel")")"
  write_file "$rel" <<EOF
# ${title}（索引）
EOF
done

write_file "docs/09-ADR-架构决策/ADR-模板.md" <<'EOF'
# ADR-YYYYMMDD-标题
## 状态
## 背景
## 决策
## 影响
## 回滚/替代
EOF

write_file "docs/09-ADR-架构决策/ADR-索引.md" <<'EOF'
# ADR 索引
EOF

# Hooks + install script.
write_file "scripts/dev/install-git-hooks.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
git config core.hooksPath .githooks
git config commit.template "$(pwd)/.github/commit_message_template.md"
chmod +x .githooks/pre-commit .githooks/commit-msg .githooks/pre-push
echo "hooks/template installed"
EOF

write_file ".githooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
if [ "$branch" = "main" ] && [ "${ALLOW_COMMIT_MAIN:-0}" != "1" ]; then
  echo "禁止在 main 直接提交，请走分支 + PR。"
  exit 1
fi
EOF

write_file ".githooks/commit-msg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
msg_file="$1"
subject="$(sed -n '1p' "$msg_file" | tr -d '\r')"
regex='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([[:alnum:]./_-]+\))?!?: .{1,72}$'
echo "$subject" | grep -Eq "$regex" || {
  echo "提交标题必须为: type(scope): summary"
  exit 1
}
EOF

write_file ".githooks/pre-push" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
scripts/docs/index-check.sh
scripts/ci/verify.sh
EOF

# CI + docs checks.
write_file "scripts/ci/verify.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
scripts/ci/lint.sh
scripts/ci/typecheck.sh
scripts/ci/test.sh
scripts/ci/build.sh
scripts/ci/coverage-check.sh
EOF

for rel in \
  "scripts/ci/lint.sh" \
  "scripts/ci/typecheck.sh" \
  "scripts/ci/test.sh" \
  "scripts/ci/build.sh" \
  "scripts/ci/coverage-check.sh"; do
  write_file "$rel" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "[ci] placeholder passed"
EOF
done

write_file "scripts/docs/index-check.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
for d in docs/00-术语表 docs/01-产品 docs/02-架构 docs/03-领域模型 docs/04-接口 docs/05-事件 docs/06-数据 docs/07-运行态 docs/08-安全 docs/09-ADR-架构决策; do
  test -d "$d" || { echo "missing dir: $d"; exit 1; }
  ls "$d"/*.md >/dev/null 2>&1 || { echo "missing index md: $d"; exit 1; }
done
test -f docs/README.md || { echo "missing docs/README.md"; exit 1; }
EOF

write_file ".github/workflows/quality-gates.yml" <<'EOF'
name: quality-gates
on: [push, pull_request]
jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: scripts/ci/verify.sh
EOF

write_file ".github/workflows/doc-check.yml" <<'EOF'
name: checks
on: [push, pull_request]
jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: scripts/docs/index-check.sh
EOF

# chmod.
for rel in \
  "scripts/dev/install-git-hooks.sh" \
  ".githooks/pre-commit" \
  ".githooks/commit-msg" \
  ".githooks/pre-push" \
  "scripts/ci/verify.sh" \
  "scripts/ci/lint.sh" \
  "scripts/ci/typecheck.sh" \
  "scripts/ci/test.sh" \
  "scripts/ci/build.sh" \
  "scripts/ci/coverage-check.sh" \
  "scripts/docs/index-check.sh"; do
  mark_executable "$rel"
done

# Global git config (optional).
if [ "$setup_global_git" -eq 1 ]; then
  if [ "$dry_run" -eq 1 ]; then
    log "run: git config --global user.name \"${git_user_name}\""
    log "run: git config --global user.email \"${git_user_email}\""
    log "run: git config --global init.defaultBranch main"
    log "run: git config --global fetch.prune true"
    log "run: git config --global core.autocrlf input"
    log "run: git config --global rerere.enabled true"
  else
    git config --global user.name "${git_user_name}"
    git config --global user.email "${git_user_email}"
    git config --global init.defaultBranch main
    git config --global fetch.prune true
    git config --global core.autocrlf input
    git config --global rerere.enabled true
    log "global git config applied"
  fi
fi

if [ "$conflicts" -gt 0 ] && [ "$force" -ne 1 ]; then
  log "summary: dirs=${dirs_created}, created=${created}, updated=${updated}, unchanged=${unchanged}, conflicts=${conflicts}"
  fail "conflicts detected; rerun with --force or resolve manually"
fi

if [ "$init_git" -eq 1 ]; then
  if [ ! -d "${target}/.git" ]; then
    run_in_target "git init -q"
    log "git repository initialized"
  fi
fi

if [ "$run_verify" -eq 1 ]; then
  run_in_target "scripts/dev/install-git-hooks.sh"
  run_in_target "scripts/docs/index-check.sh"
  run_in_target "scripts/ci/verify.sh"
fi

log "summary: dirs=${dirs_created}, created=${created}, updated=${updated}, unchanged=${unchanged}, conflicts=${conflicts}"
log "done"
log "next: cd ${target} && git checkout -b chore/bootstrap-governance && git add . && git commit"

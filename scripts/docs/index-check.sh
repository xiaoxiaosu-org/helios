#!/usr/bin/env bash
set -euo pipefail

now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log() {
  echo "[docs-index][$(now)] $*"
}

fail() {
  echo "[docs-index][$(now)] $*" >&2
  exit 1
}

start_s="$(date +%s)"
trap 'rc=$?; end_s=$(date +%s); dur=$(( end_s - start_s )); if [ "$rc" -eq 0 ]; then log "结束：成功（耗时 ${dur}s）"; else log "结束：失败（退出码 ${rc}，耗时 ${dur}s）"; fi' EXIT
log "启动：docs 索引完整性校验"

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

required_top_dirs=(
  "docs/00-术语表"
  "docs/01-产品"
  "docs/02-架构"
  "docs/03-领域模型"
  "docs/04-接口"
  "docs/05-事件"
  "docs/06-数据"
  "docs/07-运行态"
  "docs/08-安全"
  "docs/09-ADR-架构决策"
)

required_entry_files=(
  "docs/README.md"
  "docs/00-术语表/README.md"
  "docs/01-产品/README.md"
  "docs/02-架构/README.md"
  "docs/03-领域模型/README.md"
  "docs/04-接口/README.md"
  "docs/05-事件/README.md"
  "docs/06-数据/README.md"
  "docs/07-运行态/README.md"
  "docs/08-安全/README.md"
  "docs/09-ADR-架构决策/README.md"
  "docs/09-ADR-架构决策/ADR-模板.md"
  "docs/09-ADR-架构决策/ADR-索引.md"
)

for d in "${required_top_dirs[@]}"; do
  [ -d "$d" ] || fail "缺少固定 docs 顶层目录：$d"
done

for f in "${required_entry_files[@]}"; do
  [ -f "$f" ] || fail "缺少入口/索引文件：$f"
done

# Ensure docs/README.md at least references each top-level index.
for idx in "${required_entry_files[@]}"; do
  case "$idx" in
    docs/*/README.md)
      grep -F "$idx" docs/README.md >/dev/null || fail "docs/README.md 未链接到：$idx"
      ;;
  esac
done

# Progressive disclosure: if a directory accumulates many Markdown files, require a local README.md index.
# Skip machine-output directories by convention.
skip_dir_regex='^docs/(04-接口/OpenAPI|05-事件/Schemas)(/|$)'
while IFS= read -r dir; do
  echo "$dir" | grep -E "${skip_dir_regex}" >/dev/null && continue

  md_count=$(find "$dir" -maxdepth 1 -type f -name "*.md" | wc -l | tr -d ' ')
  [ "$md_count" -gt 7 ] || continue

  if [ ! -f "${dir}/README.md" ]; then
    fail "目录 Markdown 文件数=${md_count}，但缺少 README.md 索引页：${dir}"
  fi
done < <(find docs -type d -print)

log "校验通过"

#!/usr/bin/env bash
set -euo pipefail

now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log() {
  echo "[rule-docs][$(now)] $*"
}

fail() {
  echo "[rule-docs][$(now)] $*" >&2
  exit 1
}

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${root}"

changed_file_list="${1:-changed_files.txt}"
if [ ! -f "${changed_file_list}" ]; then
  log "未发现 ${changed_file_list}，跳过规则文件校验。"
  exit 0
fi

log "启动：规则文件格式与中文描述校验（基于 ${changed_file_list}）"

rule_scope_regex='(^|/)AGENTS(\..+)?$|^docs/02-架构/工程治理/'
md_rule_scope_regex='(^|/)AGENTS\.md$|^docs/02-架构/工程治理/.*\.md$'
found_rule_changes=0

while IFS= read -r f; do
  [ -n "${f}" ] || continue
  echo "${f}" | grep -E "${rule_scope_regex}" >/dev/null || continue
  found_rule_changes=1

  if ! echo "${f}" | grep -E "${md_rule_scope_regex}" >/dev/null; then
    fail "规则文件必须使用 Markdown（.md）：${f}"
  fi

  # 删除文件不校验正文。
  [ -f "${f}" ] || continue

  if ! grep -P -q '[\x{4e00}-\x{9fff}]' "${f}"; then
    fail "规则文件需包含中文描述：${f}"
  fi
done < "${changed_file_list}"

if [ "${found_rule_changes}" -eq 0 ]; then
  log "本次未检测到规则文件变更，跳过。"
  exit 0
fi

log "校验通过"

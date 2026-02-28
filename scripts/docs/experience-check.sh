#!/usr/bin/env bash
set -euo pipefail

now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log() {
  echo "[docs-exp][$(now)] $*"
}

fail() {
  echo "[docs-exp][$(now)] $*" >&2
  exit 1
}

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${root}"

exp_dir="docs/02-架构/工程治理/经验库"
index_file="${exp_dir}/README.md"

log "启动：经验库文档校验"

[ -d "${exp_dir}" ] || fail "缺少经验库目录：${exp_dir}"
[ -f "${index_file}" ] || fail "缺少经验库索引：${index_file}"

mapfile -t docs_files < <(find "${exp_dir}" -maxdepth 1 -type f -name "*.md" | sort)
[ "${#docs_files[@]}" -gt 0 ] || fail "经验库未检测到 Markdown 文档"

for f in "${docs_files[@]}"; do
  if ! grep -P -q '[\x{4e00}-\x{9fff}]' "${f}"; then
    fail "经验库文档需包含中文描述：${f}"
  fi

  base="$(basename "${f}")"
  if [ "${base}" = "README.md" ]; then
    continue
  fi

  grep -F "${base}" "${index_file}" >/dev/null || fail "经验库索引缺少文档链接：${base}"
done

log "校验通过"

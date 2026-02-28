#!/usr/bin/env bash
set -euo pipefail

now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log() {
  echo "[doc-gardening][$(now)] $*"
}

usage() {
  cat <<'USAGE'
用法：scripts/docs/gardening.sh [--out <目录>]
USAGE
}

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${root}"

out_dir="artifacts/docs/gardening"
while [ $# -gt 0 ]; do
  case "$1" in
    --out)
      out_dir="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数：$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

mkdir -p "${out_dir}"
report_md="${out_dir}/report.md"
broken_links_file="${out_dir}/broken-links.txt"
: > "${broken_links_file}"

index_result="PASS"
if ! scripts/docs/index-check.sh > "${out_dir}/index-check.log" 2>&1; then
  index_result="FAIL"
fi

while IFS='|' read -r file line target; do
  case "${target}" in
    http://*|https://*|mailto:*|\#*|'') continue ;;
  esac
  path_part="${target%%#*}"
  [ -n "${path_part}" ] || continue
  if [[ "${path_part}" = /* ]]; then
    resolved="${path_part}"
  else
    resolved="$(cd "$(dirname "${file}")" && realpath -m "${path_part}")"
  fi
  if [ ! -e "${resolved}" ]; then
    echo "${file}:${line} -> ${target}" >> "${broken_links_file}"
  fi
done < <(perl -ne 'while(/\[[^\]]+\]\(([^)]+)\)/g){print "$ARGV|$.|$1\n"}' $(find docs .github -maxdepth 4 -type f -name '*.md' -print) AGENTS.md)

broken_count="$(wc -l < "${broken_links_file}" | tr -d ' ')"
link_result="PASS"
if [ "${broken_count}" -gt 0 ]; then
  link_result="FAIL"
fi

generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  echo "# Doc Gardening 报告"
  echo
  echo "- 生成时间(UTC): ${generated_at}"
  echo "- 索引检查: ${index_result}"
  echo "- 链接检查: ${link_result}"
  echo "- 断链数量: ${broken_count}"
  echo
  echo "## 产物"
  echo "- index log: ${out_dir}/index-check.log"
  echo "- broken links: ${out_dir}/broken-links.txt"
  if [ "${broken_count}" -gt 0 ]; then
    echo
    echo "## 断链详情"
    sed 's/^/- /' "${broken_links_file}"
  fi
} > "${report_md}"

if [ "${index_result}" = "FAIL" ] || [ "${link_result}" = "FAIL" ]; then
  log "失败：Doc gardening 检测未通过（报告：${report_md}）"
  exit 1
fi

log "通过：Doc gardening 检测通过（报告：${report_md}）"

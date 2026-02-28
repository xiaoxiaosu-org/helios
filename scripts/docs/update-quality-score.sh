#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${root}"

quality_file="docs/02-架构/质量评分与演进.md"
sync_out=""
mode="write"

usage() {
  cat <<'USAGE'
用法：scripts/docs/update-quality-score.sh [--check] [--sync-out <dir>]
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check)
      mode="check"
      shift
      ;;
    --sync-out)
      sync_out="${2:-}"
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

[ -f "${quality_file}" ] || {
  echo "[quality-score] 缺少文件：${quality_file}" >&2
  exit 1
}

if [ -n "${sync_out}" ] && [ -f "${sync_out}/cap-status.tsv" ]; then
  status_tsv="${sync_out}/cap-status.tsv"
else
  tmp_sync="$(mktemp -d)"
  scripts/ci/cap-plan-sync-check.sh --allow-drift --out "${tmp_sync}" >/dev/null
  status_tsv="${tmp_sync}/cap-status.tsv"
fi

generated_at="$(awk -F': ' '/^- 自动汇总基线\(UTC\): / {print $2; exit}' "${quality_file}" || true)"
if [ -z "${generated_at}" ]; then
  generated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
fi
drift_count="$(awk -F '\t' '$5=="drift"{c++} END{print c+0}' "${status_tsv}")"

block_file="$(mktemp)"
{
  echo "<!-- AUTO-QUALITY-SCORE:BEGIN -->"
  echo "## 自动更新时间"
  echo
  echo "- 自动汇总基线(UTC): ${generated_at}"
  echo "- 数据来源: scripts/ci/cap-plan-sync-check.sh"
  echo
  echo "## CAP 验收状态汇总（自动生成）"
  echo
  echo "| CAP | 路线图状态 | 验收结果 | 返回码 | 状态同步 |"
  echo "|---|---|---|---|---|"
  while IFS=$'\t' read -r cap_id plan_state runtime_state rc sync_state; do
    [ -n "${cap_id}" ] || continue
    printf '| %s | %s | %s | %s | %s |\n' "${cap_id}" "${plan_state}" "${runtime_state}" "${rc}" "${sync_state}"
  done < "${status_tsv}"
  echo
  echo "- 漂移项数量: ${drift_count}"
  echo "<!-- AUTO-QUALITY-SCORE:END -->"
} > "${block_file}"

candidate_file="$(mktemp)"
awk -v block_file="${block_file}" '
  BEGIN {
    while ((getline line < block_file) > 0) {
      block = block line "\n"
    }
    close(block_file)
  }
  /<!-- AUTO-QUALITY-SCORE:BEGIN -->/ {
    printf "%s", block
    in_auto=1
    next
  }
  /<!-- AUTO-QUALITY-SCORE:END -->/ {
    in_auto=0
    seen=1
    next
  }
  !in_auto { print }
  END {
    if (seen == 0) {
      print ""
      printf "%s", block
    }
  }
' "${quality_file}" > "${candidate_file}"

if [ "${mode}" = "check" ]; then
  if ! diff -u "${quality_file}" "${candidate_file}" >/dev/null; then
    echo "[quality-score] 检测到质量评分文档未同步自动汇总区块。" >&2
    echo "[quality-score] 下一步：执行 scripts/docs/update-quality-score.sh 后提交文档。" >&2
    exit 1
  fi
  echo "[quality-score] 通过：自动汇总区块已同步"
  exit 0
fi

mv "${candidate_file}" "${quality_file}"
echo "[quality-score] 已更新：${quality_file}"

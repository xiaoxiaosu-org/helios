#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
source "${here}/_lib.sh"

ci_begin "结构化日志门禁（logging-check）"

out_dir="artifacts/ci/logging-check"
while [ $# -gt 0 ]; do
  case "$1" in
    --out)
      out_dir="${2:-}"
      shift 2
      ;;
    *)
      echo "用法：scripts/ci/logging-check.sh [--out <dir>]" >&2
      exit 1
      ;;
  esac
done

mkdir -p "${out_dir}"
report_txt="${out_dir}/logging-check-report.txt"
report_json="${out_dir}/logging-check-report.json"
: > "${report_txt}"

if ! has_any_code_dir; then
  {
    echo "status=pass"
    echo "reason=未检测到业务代码目录，跳过结构化日志检查"
  } > "${report_txt}"
  cat > "${report_json}" <<JSON
{
  "status": "pass",
  "reason": "no-code-dir",
  "issues": []
}
JSON
  log "通过：未检测到业务代码目录，跳过"
  exit 0
fi

# Baseline rule: logger.<level>("...") 单字符串消息视为未结构化，要求至少带上下文字段。
code_file_regex='\.(ts|tsx|js|jsx|java|kt|py|go|rb|php|cs|scala)$'
level_regex='trace|debug|info|warn|error|fatal'
unstructured_regex="\\blogger\\.(${level_regex})\\(\\s*['\"][^'\"]*['\"]\\s*\\)"

hits_file="${out_dir}/unstructured-logging-hits.txt"
: > "${hits_file}"

while IFS= read -r f; do
  [ -f "${f}" ] || continue
  echo "${f}" | grep -E "${code_file_regex}" >/dev/null || continue
  echo "${f}" | grep -E '(^|/)(test|tests|__tests__|spec|specs)/' >/dev/null && continue
  rg -n --pcre2 "${unstructured_regex}" "${f}" >> "${hits_file}" || true
done < <(find modules apps services src -type f 2>/dev/null || true)

issue_count="$(wc -l < "${hits_file}" | tr -d ' ')"
if [ "${issue_count}" -gt 0 ]; then
  {
    echo "status=fail"
    echo "issues=${issue_count}"
    echo "rule=禁止无上下文的 logger.<level>(\"...\")"
    echo "next=改为结构化日志（例如 logger.info({traceId, workflowInstanceId, stepId}, \"message\")）"
    echo "---"
    cat "${hits_file}"
  } > "${report_txt}"

  {
    echo "{"
    echo "  \"status\": \"fail\","
    echo "  \"issueCount\": ${issue_count},"
    echo "  \"rule\": \"no-plain-string-logger\","
    echo "  \"next\": \"use structured logger fields\","
    echo "  \"issues\": ["
    awk '{
      gsub(/\\/,"\\\\",$0)
      gsub(/"/,"\\\"",$0)
      printf "    \"%s\"", $0
      if (NR > 0) {
        printf ","
      }
      printf "\n"
    }' "${hits_file}" | sed '$ s/,$//'
    echo "  ]"
    echo "}"
  } > "${report_json}"

  cat "${report_txt}" >&2
  exit 1
fi

{
  echo "status=pass"
  echo "issues=0"
  echo "rule=禁止无上下文的 logger.<level>(\"...\")"
} > "${report_txt}"

cat > "${report_json}" <<JSON
{
  "status": "pass",
  "issueCount": 0,
  "rule": "no-plain-string-logger",
  "issues": []
}
JSON

log "通过：结构化日志检查通过（报告：${report_txt}）"

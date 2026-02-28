#!/usr/bin/env bash
set -euo pipefail

now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log() {
  echo "[docs-library][$(now)] $*"
}

usage() {
  cat <<'USAGE'
用法：
  scripts/docs/library-check.sh [all|index|rules|governance|gardening|experience] [--out <目录>]
USAGE
}

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${root}"

module="all"
out_dir="artifacts/ci/doc-library"
status_dir=""
all_started_at="$(now)"

while [ $# -gt 0 ]; do
  case "$1" in
    all|index|rules|governance|gardening|experience)
      module="$1"
      shift
      ;;
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
status_dir="${out_dir}/module-status"
mkdir -p "${status_dir}"

write_module_status() {
  local target_module="$1"
  local rc="$2"
  local started_at="$3"
  local ended_at
  local status
  local ok
  local file
  local tmp

  ended_at="$(now)"
  if [ "${rc}" -eq 0 ]; then
    status="PASS"
    ok="true"
  else
    status="FAIL"
    ok="false"
  fi

  file="${status_dir}/${target_module}.json"
  tmp="$(mktemp)"
  cat > "${tmp}" <<EOF
{
  "module": "${target_module}",
  "status": "${status}",
  "ok": ${ok},
  "startedAt": "${started_at}",
  "endedAt": "${ended_at}",
  "outDir": "${out_dir}"
}
EOF
  mv "${tmp}" "${file}"
}

finalize_all_status() {
  local rc="$1"
  write_module_status "all" "${rc}" "${all_started_at}"
}

trap 'finalize_all_status "$?"' EXIT

run_index() {
  scripts/docs/index-check.sh
}

run_rules() {
  local changed_file_list
  local rc
  changed_file_list="$(mktemp)"
  {
    echo "AGENTS.md"
    find docs/02-架构/工程治理 -type f -name "*.md" | sort
  } > "${changed_file_list}"
  set +e
  scripts/docs/rule-files-check.sh "${changed_file_list}"
  rc=$?
  set -e
  rm -f "${changed_file_list}"
  return "${rc}"
}

run_governance() {
  scripts/docs/git-governance-sync-check.sh
}

run_gardening() {
  scripts/docs/gardening.sh --out "${out_dir}/gardening"
}

run_experience() {
  scripts/docs/experience-check.sh
}

run_module() {
  local target_module="$1"
  local started_at
  local rc
  started_at="$(now)"

  set +e
  case "${target_module}" in
    index)
      run_index
      rc=$?
      ;;
    rules)
      run_rules
      rc=$?
      ;;
    governance)
      run_governance
      rc=$?
      ;;
    gardening)
      run_gardening
      rc=$?
      ;;
    experience)
      run_experience
      rc=$?
      ;;
    *)
      echo "未知模块：${target_module}" >&2
      rc=1
      ;;
  esac
  set -e

  if [ "${rc}" -eq 0 ]; then
    write_module_status "${target_module}" 0 "${started_at}"
    return 0
  fi

  write_module_status "${target_module}" "${rc}" "${started_at}"
  return "${rc}"
}

log "启动：文档库逻辑校验与统一（module=${module}）"

case "${module}" in
  index)
    run_module "index"
    ;;
  rules)
    run_module "rules"
    ;;
  governance)
    run_module "governance"
    ;;
  gardening)
    run_module "gardening"
    ;;
  experience)
    run_module "experience"
    ;;
  all)
    run_module "index"
    run_module "rules"
    run_module "experience"
    run_module "governance"
    run_module "gardening"
    ;;
esac

log "校验通过（module=${module}）"

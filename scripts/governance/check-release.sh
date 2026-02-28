#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
用法：scripts/governance/check-release.sh [--lock <file>] [--out <env-file>]

输出 env：
- UPDATE_AVAILABLE=0|1
- CURRENT_COMMIT=<sha|empty>
- LATEST_COMMIT=<sha|empty>
- SOURCE_REPO=<repo>
- SOURCE_REF=<ref>
USAGE
}

log() {
  echo "[governance-release] $*"
}

fail() {
  echo "[governance-release] ERROR: $*" >&2
  exit 1
}

lock_file="governance.lock"
out_file=""

while [ $# -gt 0 ]; do
  case "$1" in
    --lock)
      lock_file="${2:-}"
      shift 2
      ;;
    --out)
      out_file="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "未知参数：$1"
      ;;
  esac
done

[ -f "${lock_file}" ] || fail "缺少锁文件：${lock_file}"
# shellcheck disable=SC1090
source "${lock_file}"

update_available=0
latest_commit=""
current_commit="${GOVERNANCE_SOURCE_COMMIT:-}"
source_repo="${GOVERNANCE_SOURCE_REPO:-}"
source_ref="${GOVERNANCE_SOURCE_REF:-main}"

if [ "${GOVERNANCE_ROLE:-consumer}" = "source" ]; then
  log "source 模式默认不执行自动升级检测"
else
  [ -n "${source_repo}" ] || fail "consumer 模式缺少 GOVERNANCE_SOURCE_REPO"

  latest_commit="$(git ls-remote "${source_repo}" "${source_ref}" | awk '{print $1}' | head -n 1)"
  [ -n "${latest_commit}" ] || fail "无法读取远端 commit：repo=${source_repo} ref=${source_ref}"

  if [ -z "${current_commit}" ] || [ "${current_commit}" != "${latest_commit}" ]; then
    update_available=1
  fi
fi

if [ -n "${out_file}" ]; then
  mkdir -p "$(dirname "${out_file}")"
  cat > "${out_file}" <<ENV
UPDATE_AVAILABLE=${update_available}
CURRENT_COMMIT=${current_commit}
LATEST_COMMIT=${latest_commit}
SOURCE_REPO=${source_repo}
SOURCE_REF=${source_ref}
ENV
fi

log "update_available=${update_available} current=${current_commit:-none} latest=${latest_commit:-none}"

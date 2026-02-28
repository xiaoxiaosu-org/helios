#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
用法：scripts/governance/enforce-lock.sh

行为：
- 校验 governance.lock 基本字段是否存在。
- role=source: 校验清单文件存在（不做远端漂移对比）。
- role=consumer: 触发 scripts/governance/sync-baseline.sh --check。
USAGE
}

log() {
  echo "[governance-lock] $*"
}

fail() {
  echo "[governance-lock] ERROR: $*" >&2
  exit 1
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${repo_root}"

[ -f governance.lock ] || fail "缺少 governance.lock"
# shellcheck disable=SC1091
source governance.lock

required_keys=(
  GOVERNANCE_ROLE
  GOVERNANCE_BASELINE_VERSION
  GOVERNANCE_MANIFEST
)
for key in "${required_keys[@]}"; do
  if [ -z "${!key:-}" ]; then
    fail "governance.lock 缺少字段：${key}"
  fi
done

[ -f "${GOVERNANCE_MANIFEST}" ] || fail "缺少治理清单：${GOVERNANCE_MANIFEST}"

case "${GOVERNANCE_ROLE}" in
  source)
    log "source 模式：仅做本地结构校验（跳过远端漂移检查）"
    ;;
  consumer)
    [ -n "${GOVERNANCE_SOURCE_REPO:-}" ] || fail "consumer 模式要求 GOVERNANCE_SOURCE_REPO"
    [ -n "${GOVERNANCE_SOURCE_REF:-}" ] || fail "consumer 模式要求 GOVERNANCE_SOURCE_REF"
    scripts/governance/sync-baseline.sh --check --target .
    ;;
  *)
    fail "GOVERNANCE_ROLE 仅支持 source|consumer"
    ;;
esac

log "通过：governance.lock 校验成功"

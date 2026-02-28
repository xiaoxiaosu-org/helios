#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
用法：scripts/governance/sync-baseline.sh [options]

选项：
  --target <dir>           目标仓库目录（默认：当前目录）
  --source-repo <url>      治理基线仓库（默认：governance.lock）
  --source-ref <ref>       治理基线分支/标签/提交（默认：governance.lock）
  --manifest <path>        清单路径（默认：governance/baseline/manifest.txt）
  --role <source|consumer> 写入 governance.lock 的角色（默认：consumer）
  --check                  仅检查漂移，不写入文件
  --force                  覆盖目标中已存在且内容不同的文件
  -h, --help               显示帮助
USAGE
}

log() {
  echo "[governance-sync] $*"
}

fail() {
  echo "[governance-sync] ERROR: $*" >&2
  exit 1
}

load_lock_defaults() {
  local lock_file="$1"
  if [ ! -f "${lock_file}" ]; then
    return 0
  fi
  # shellcheck disable=SC1090
  source "${lock_file}"

  source_repo="${source_repo:-${GOVERNANCE_SOURCE_REPO:-}}"
  source_ref="${source_ref:-${GOVERNANCE_SOURCE_REF:-}}"
  manifest_rel="${manifest_rel:-${GOVERNANCE_MANIFEST:-governance/baseline/manifest.txt}}"
}

extract_commit() {
  local repo_root="$1"
  local ref="$2"
  (
    cd "${repo_root}"
    git rev-parse --verify "${ref}^{commit}" 2>/dev/null || git rev-parse --verify "${ref}" 2>/dev/null
  )
}

copy_one() {
  local src_root="$1"
  local dst_root="$2"
  local rel="$3"
  local force_mode="$4"
  local check_mode="$5"

  local src="${src_root}/${rel}"
  local dst="${dst_root}/${rel}"

  if [ ! -f "${src}" ]; then
    fail "清单项不存在：${rel}（源：${src}）"
  fi

  if [ -f "${dst}" ] && cmp -s "${src}" "${dst}"; then
    unchanged=$((unchanged + 1))
    return 0
  fi

  if [ "${check_mode}" -eq 1 ]; then
    drift=$((drift + 1))
    echo "${rel}" >> "${drift_file}"
    return 0
  fi

  mkdir -p "$(dirname "${dst}")"

  if [ -f "${dst}" ]; then
    if [ "${force_mode}" -eq 1 ]; then
      cp "${src}" "${dst}"
      updated=$((updated + 1))
      return 0
    fi
    conflicts=$((conflicts + 1))
    echo "${rel}" >> "${conflict_file}"
    return 0
  fi

  cp "${src}" "${dst}"
  created=$((created + 1))
}

target="."
source_repo=""
source_ref=""
manifest_rel="governance/baseline/manifest.txt"
role="consumer"
check_mode=0
force_mode=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      target="${2:-}"
      shift 2
      ;;
    --source-repo)
      source_repo="${2:-}"
      shift 2
      ;;
    --source-ref)
      source_ref="${2:-}"
      shift 2
      ;;
    --manifest)
      manifest_rel="${2:-}"
      shift 2
      ;;
    --role)
      role="${2:-}"
      shift 2
      ;;
    --check)
      check_mode=1
      shift
      ;;
    --force)
      force_mode=1
      shift
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

case "${role}" in
  source|consumer) ;;
  *) fail "--role 仅支持 source|consumer" ;;
esac

target="$(cd "${target}" 2>/dev/null && pwd || true)"
[ -n "${target}" ] || fail "目标目录不存在"

load_lock_defaults "${target}/governance.lock"

if [ -z "${source_repo}" ]; then
  if git -C "${target}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    source_repo="$(git -C "${target}" remote get-url origin 2>/dev/null || true)"
  fi
fi

[ -n "${source_repo}" ] || fail "缺少 --source-repo，且 governance.lock 中未提供默认值"
source_ref="${source_ref:-main}"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

source_root="${tmp_dir}/source"
log "拉取治理基线：repo=${source_repo} ref=${source_ref}"

git clone --depth 1 --branch "${source_ref}" "${source_repo}" "${source_root}" >/dev/null 2>&1 || {
  git clone --depth 1 "${source_repo}" "${source_root}" >/dev/null 2>&1
  (
    cd "${source_root}"
    git checkout --quiet "${source_ref}"
  )
}

source_commit="$(extract_commit "${source_root}" "${source_ref}")"
[ -n "${source_commit}" ] || fail "无法解析 source-ref=${source_ref}"

manifest_file="${source_root}/${manifest_rel}"
[ -f "${manifest_file}" ] || fail "基线清单不存在：${manifest_rel}"

baseline_version="unknown"
if [ -f "${source_root}/governance/baseline/VERSION" ]; then
  baseline_version="$(tr -d '[:space:]' < "${source_root}/governance/baseline/VERSION")"
fi

drift_file="${tmp_dir}/drift.txt"
conflict_file="${tmp_dir}/conflict.txt"
: > "${drift_file}"
: > "${conflict_file}"

created=0
updated=0
unchanged=0
drift=0
conflicts=0

while IFS= read -r rel || [ -n "${rel}" ]; do
  rel="${rel%%$'\r'}"
  [ -n "${rel}" ] || continue
  case "${rel}" in
    \#*)
      continue
      ;;
  esac

  copy_one "${source_root}" "${target}" "${rel}" "${force_mode}" "${check_mode}"
done < "${manifest_file}"

if [ "${check_mode}" -eq 1 ]; then
  if [ "${drift}" -gt 0 ]; then
    log "检测到治理漂移（${drift} 个文件）："
    cat "${drift_file}" >&2
    exit 1
  fi
  log "通过：治理基线与锁文件一致"
  exit 0
fi

if [ "${conflicts}" -gt 0 ]; then
  log "存在冲突（${conflicts} 个文件），请使用 --force 覆盖或手工处理："
  cat "${conflict_file}" >&2
  exit 1
fi

now_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
cat > "${target}/governance.lock" <<LOCK
GOVERNANCE_ROLE=${role}
GOVERNANCE_BASELINE_VERSION=${baseline_version}
GOVERNANCE_SOURCE_REPO=${source_repo}
GOVERNANCE_SOURCE_REF=${source_ref}
GOVERNANCE_SOURCE_COMMIT=${source_commit}
GOVERNANCE_MANIFEST=${manifest_rel}
GOVERNANCE_LAST_SYNCED_AT=${now_utc}
LOCK

log "完成：created=${created} updated=${updated} unchanged=${unchanged}"
log "lock: governance.lock"

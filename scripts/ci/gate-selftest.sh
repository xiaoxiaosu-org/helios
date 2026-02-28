#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"
source "${here}/_lib.sh"

ci_begin "门禁自测（gate-selftest）"

out_dir="${1:-artifacts/ci/gate-selftest}"
mkdir -p "${out_dir}"
report_file="${out_dir}/gate-selftest-report.txt"
: > "${report_file}"

pass_count=0
fail_count=0

log_case() {
  local status="$1"
  local name="$2"
  printf '[%s] %s\n' "${status}" "${name}" | tee -a "${report_file}"
}

pass_case() {
  pass_count=$((pass_count + 1))
  log_case "PASS" "$1"
}

fail_case() {
  fail_count=$((fail_count + 1))
  log_case "FAIL" "$1"
}

expect_pass() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    pass_case "${name}"
  else
    fail_case "${name}"
  fi
}

expect_fail() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    fail_case "${name}"
  else
    pass_case "${name}"
  fi
}

# ---------- CAP-004 / arch-check 自测 ----------
selftest_id="selftest-$$"
arch_mod_dir="modules/__gate_selftest__/${selftest_id}"
arch_svc_dir="services/__gate_selftest__/${selftest_id}"
arch_tmp_out="$(mktemp -d "${TMPDIR:-/tmp}/gate-selftest-arch.XXXXXX")"

cleanup_arch() {
  rm -rf "${arch_mod_dir}" "${arch_svc_dir}" "${arch_tmp_out}" 2>/dev/null || true
  rmdir modules/__gate_selftest__ services/__gate_selftest__ 2>/dev/null || true
  rmdir modules services 2>/dev/null || true
}
trap 'cleanup_arch' EXIT

mkdir -p "${arch_mod_dir}" "${arch_svc_dir}"
cat > "${arch_svc_dir}/dep.ts" <<'TS'
export const dep = 1
TS

cat > "${arch_mod_dir}/a.ts" <<'TS'
import { dep } from "../../../services/__gate_selftest__/selftest-placeholder/dep"
export const a = dep
TS
# 将 placeholder 替换为当前 selftest_id
sed -i "s/selftest-placeholder/${selftest_id}/g" "${arch_mod_dir}/a.ts"

expect_fail "arch-check 拦截 modules -> services 非法依赖" \
  scripts/ci/arch-check.sh --out "${arch_tmp_out}"

cat > "${arch_mod_dir}/b.ts" <<'TS'
export const b = 2
TS
cat > "${arch_mod_dir}/a.ts" <<'TS'
import { b } from "./b"
export const a = b
TS

expect_pass "arch-check 放行 modules -> modules 合法依赖" \
  scripts/ci/arch-check.sh --out "${arch_tmp_out}"

cleanup_arch
trap - EXIT

# ---------- CAP-007 / 技术债清单校验自测 ----------
tech_debt_file="docs/02-架构/技术债清单.md"
backup_file="$(mktemp "${TMPDIR:-/tmp}/tech-debt.XXXXXX")"
cp "${tech_debt_file}" "${backup_file}"
cap_tmp_out="$(mktemp -d "${TMPDIR:-/tmp}/gate-selftest-cap007.XXXXXX")"

restore_tech_debt() {
  cp "${backup_file}" "${tech_debt_file}"
}

cleanup_cap() {
  restore_tech_debt
  rm -f "${backup_file}" 2>/dev/null || true
  rm -rf "${cap_tmp_out}" 2>/dev/null || true
}
trap 'cleanup_cap' EXIT

expect_pass "CAP-007 正常清单应通过" \
  env ARTIFACT_DIR="${cap_tmp_out}" scripts/cap/CAP-007/verify.sh

sed -i 's/| 最近更新 |/| 最近更新时间 |/' "${tech_debt_file}"
expect_fail "CAP-007 缺少关键字段应失败" \
  env ARTIFACT_DIR="${cap_tmp_out}" scripts/cap/CAP-007/verify.sh
restore_tech_debt

sed -i '0,/| In Progress |/s//| Pending |/' "${tech_debt_file}"
expect_fail "CAP-007 TD 行状态非法应失败" \
  env ARTIFACT_DIR="${cap_tmp_out}" scripts/cap/CAP-007/verify.sh
restore_tech_debt

# ---------- 技术债治理检查自测 ----------
expect_pass "tech-debt-governance 正常清单应通过" \
  scripts/ci/tech-debt-governance-check.sh --out "${cap_tmp_out}"

sed -i 's/| 最近更新 |/| 最近更新时间 |/' "${tech_debt_file}"
expect_fail "tech-debt-governance 缺少关键字段应失败" \
  scripts/ci/tech-debt-governance-check.sh --out "${cap_tmp_out}"
restore_tech_debt

sed -i '0,/2026-02-28/s//2026-02-20/' "${tech_debt_file}"
expect_fail "tech-debt-governance 超过 7 天未更新且无阻塞说明应失败" \
  scripts/ci/tech-debt-governance-check.sh --out "${cap_tmp_out}"
restore_tech_debt

# ---------- workflow-sync 联动检查自测 ----------
sync_changed_ok="$(mktemp "${TMPDIR:-/tmp}/workflow-sync-ok.XXXXXX")"
sync_changed_fail="$(mktemp "${TMPDIR:-/tmp}/workflow-sync-fail.XXXXXX")"
printf '%s\n%s\n' "scripts/ci/arch-check.sh" "docs/02-架构/技术债清单.md" > "${sync_changed_ok}"
printf '%s\n' "scripts/ci/arch-check.sh" > "${sync_changed_fail}"

expect_pass "workflow-sync 触发改动且同步文档应通过" \
  scripts/ci/workflow-sync-check.sh "${sync_changed_ok}"
expect_fail "workflow-sync 触发改动未同步文档应失败" \
  scripts/ci/workflow-sync-check.sh "${sync_changed_fail}"

rm -f "${sync_changed_ok}" "${sync_changed_fail}"

cleanup_cap
trap - EXIT

{
  echo "通过用例：${pass_count}"
  echo "失败用例：${fail_count}"
  echo "报告文件：${report_file}"
} | tee -a "${report_file}"

if [ "${fail_count}" -gt 0 ]; then
  log "失败：gate-selftest 发现 ${fail_count} 个异常（报告：${report_file}）"
  exit 1
fi

log "通过：gate-selftest 全部通过（报告：${report_file}）"

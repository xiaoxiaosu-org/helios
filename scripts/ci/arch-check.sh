#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"
source "${here}/_lib.sh"

usage() {
  cat >&2 <<'USAGE'
用法：scripts/ci/arch-check.sh [--out <dir>]

说明：
- 校验顶层代码目录（apps/services/modules/src）之间的依赖方向
- 规则来源：docs/02-架构/边界与依赖规则.md
USAGE
}

out_dir=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --out)
      [ "$#" -ge 2 ] || { usage; exit 3; }
      out_dir="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[arch-check] 未知参数：$1" >&2
      usage
      exit 3
      ;;
  esac
done

if [ -z "${out_dir}" ]; then
  out_dir="$(mktemp -d "${TMPDIR:-/tmp}/arch-check.XXXXXX")"
fi
mkdir -p "${out_dir}"
report_file="${out_dir}/arch-check-report.txt"

ci_begin "架构边界/依赖方向门禁（arch-check）"

rule_file="docs/02-架构/边界与依赖规则.md"
if [ ! -f "${rule_file}" ]; then
  {
    echo "失败：缺少规则文件 ${rule_file}"
    echo "下一步：新增 ${rule_file}，明确目录边界与依赖方向后重试。"
    echo "下一步命令：scripts/ci/arch-check.sh --out ${out_dir}"
  } | tee "${report_file}" >&2
  exit 1
fi

mapfile -t code_files < <(
  rg --files modules apps services src 2>/dev/null \
    | rg -N '\.(js|jsx|ts|tsx|mjs|cjs|py|java|kt|go|rb|php|cs|scala)$' \
    || true
)

if [ "${#code_files[@]}" -eq 0 ]; then
  {
    echo "通过：未检测到目标代码文件，当前无需执行跨目录依赖检查。"
    echo "规则文件：${rule_file}"
    echo "检查目录：apps/ services/ modules/ src/"
  } > "${report_file}"
  log "通过：未发现可检查代码文件（报告：${report_file}）"
  exit 0
fi

allow_targets() {
  case "$1" in
    apps) echo "apps services modules" ;;
    services) echo "services modules" ;;
    modules) echo "modules" ;;
    src) echo "src" ;;
    *) echo "" ;;
  esac
}

is_allowed_target() {
  local src_layer="$1"
  local target_layer="$2"
  local allowed
  allowed="$(allow_targets "${src_layer}")"
  for t in ${allowed}; do
    if [ "${t}" = "${target_layer}" ]; then
      return 0
    fi
  done
  return 1
}

extract_targets() {
  local file="$1"
  # 提取常见语言 import/require/from 的依赖目标
  {
    rg -No "(?:from|import|require\\()\\s*['\"]([^'\"]+)['\"]" "$file" 2>/dev/null \
      | sed -E "s/.*['\"]([^'\"]+)['\"].*/\\1/"
    rg -No "^[[:space:]]*(?:from|import)[[:space:]]+([A-Za-z_][A-Za-z0-9_\\.]*)" "$file" 2>/dev/null \
      | sed -E "s/^[[:space:]]*(?:from|import)[[:space:]]+([A-Za-z_][A-Za-z0-9_\\.]*).*/\\1/"
  } | awk 'NF > 0' | sort -u || true
}

resolve_target_layer() {
  local src_file="$1"
  local raw_target="$2"
  local src_dir
  src_dir="$(dirname "${src_file}")"

  case "${raw_target}" in
    apps/*|services/*|modules/*|src/*)
      echo "${raw_target%%/*}"
      return 0
      ;;
    apps.*|services.*|modules.*|src.*)
      echo "${raw_target%%.*}"
      return 0
      ;;
    @/*)
      # 约定 @/ 指向 src/
      echo "src"
      return 0
      ;;
    ./*|../*)
      local abs
      abs="$(realpath -m "${src_dir}/${raw_target}")"
      local rel
      rel="${abs#${repo_root}/}"
      case "${rel}" in
        apps/*|services/*|modules/*|src/*)
          echo "${rel%%/*}"
          return 0
          ;;
      esac
      ;;
  esac

  echo ""
}

violations=()
checked_edges=0

for file in "${code_files[@]}"; do
  src_layer="${file%%/*}"
  case "${src_layer}" in
    apps|services|modules|src) ;;
    *) continue ;;
  esac

  while IFS= read -r target; do
    [ -n "${target}" ] || continue
    target_layer="$(resolve_target_layer "${file}" "${target}")"
    [ -n "${target_layer}" ] || continue

    checked_edges=$((checked_edges + 1))
    if ! is_allowed_target "${src_layer}" "${target_layer}"; then
      violations+=("${file}: ${src_layer} -> ${target_layer}（import: ${target}）")
    fi
  done < <(extract_targets "${file}")
done

if [ "${#violations[@]}" -gt 0 ]; then
  {
    echo "失败：检测到 ${#violations[@]} 条架构依赖违规。"
    echo "规则文件：${rule_file}"
    echo "违规明细："
    printf '%s\n' "${violations[@]}"
    echo
    echo "下一步：根据 ${rule_file} 调整依赖方向（建议先从 import 路径修复）。"
    echo "下一步命令：scripts/ci/arch-check.sh --out ${out_dir}"
  } | tee "${report_file}" >&2
  exit 1
fi

{
  echo "通过：未检测到架构依赖违规。"
  echo "规则文件：${rule_file}"
  echo "扫描文件数：${#code_files[@]}"
  echo "解析依赖边数：${checked_edges}"
} > "${report_file}"

log "通过：arch-check 完成（报告：${report_file}）"

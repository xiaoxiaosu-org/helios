#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"
source "${here}/_lib.sh"

map_file="docs/02-架构/执行计划/workflow-map.yaml"
changed_files_input="${1:-}"
tech_debt_file="$(awk -F': ' '/^[[:space:]]*tech_debt_file:/ {print $2; exit}' "${map_file}")"

if [ ! -f "${map_file}" ]; then
  echo "[workflow-sync] 缺少 workflow map：${map_file}" >&2
  exit 1
fi

git config core.quotepath false >/dev/null 2>&1 || true

tmp_changed="$(mktemp)"
if [ -n "${changed_files_input}" ] && [ -f "${changed_files_input}" ]; then
  cp "${changed_files_input}" "${tmp_changed}"
else
  git diff --name-only > "${tmp_changed}" 2>/dev/null || true
  git ls-files --others --exclude-standard >> "${tmp_changed}" 2>/dev/null || true
  sort -u "${tmp_changed}" -o "${tmp_changed}"
fi

if [ ! -s "${tmp_changed}" ]; then
  log "通过：无变更文件，跳过 workflow-sync 检查"
  rm -f "${tmp_changed}"
  exit 0
fi

fail_file="$(mktemp)"
: > "${fail_file}"

active_td_file="$(mktemp)"
awk -F'|' '
  function trim(s) {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
    return s
  }
  /^## 在制技术债/ { section="open"; next }
  /^## 已完成/ { section="done"; next }
  section == "open" && /^\| TD-[0-9]{3} / {
    print trim($2)
  }
' "${tech_debt_file}" > "${active_td_file}"

awk '
  function trim(s) {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
    return s
  }
  /^[[:space:]]*-[[:space:]]*td_id:[[:space:]]*/ {
    if (td != "") {
      printf "%s\t%s\t%s\n", td, trigger_paths, required_docs
    }
    td=$0
    sub(/^[[:space:]]*-[[:space:]]*td_id:[[:space:]]*/, "", td)
    td=trim(td)
    trigger_paths=""
    required_docs=""
    next
  }
  /^[[:space:]]*trigger_paths:[[:space:]]*/ {
    v=$0
    sub(/^[[:space:]]*trigger_paths:[[:space:]]*/, "", v)
    trigger_paths=trim(v)
    next
  }
  /^[[:space:]]*required_docs:[[:space:]]*/ {
    v=$0
    sub(/^[[:space:]]*required_docs:[[:space:]]*/, "", v)
    required_docs=trim(v)
    next
  }
  END {
    if (td != "") {
      printf "%s\t%s\t%s\n", td, trigger_paths, required_docs
    }
  }
' "${map_file}" | while IFS=$'\t' read -r td_id trigger_paths required_docs; do
  [ -n "${td_id}" ] || continue
  if ! grep -Fx "${td_id}" "${active_td_file}" >/dev/null; then
    continue
  fi

  triggered=0
  IFS=';' read -r -a trigger_arr <<< "${trigger_paths}"
  for p in "${trigger_arr[@]}"; do
    p="$(echo "${p}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "${p}" ] || continue
    if grep -E "^${p//\//\\/}" "${tmp_changed}" >/dev/null; then
      triggered=1
      break
    fi
  done

  [ "${triggered}" -eq 1 ] || continue

  doc_changed=0
  IFS=';' read -r -a doc_arr <<< "${required_docs}"
  for d in "${doc_arr[@]}"; do
    d="$(echo "${d}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "${d}" ] || continue
    if grep -Fx "${d}" "${tmp_changed}" >/dev/null; then
      doc_changed=1
      break
    fi
  done

  if [ "${doc_changed}" -eq 0 ]; then
    {
      echo "[workflow-sync] ${td_id} 触发了代码/门禁变更，但未同步必需文档。"
      echo "  - 触发路径: ${trigger_paths}"
      echo "  - 必需文档(至少一项): ${required_docs}"
    } >> "${fail_file}"
  fi
done

if [ -s "${fail_file}" ]; then
  cat "${fail_file}" >&2
  rm -f "${tmp_changed}" "${fail_file}" "${active_td_file}"
  exit 1
fi

log "通过：workflow-sync 文档联动检查通过"
rm -f "${tmp_changed}" "${fail_file}" "${active_td_file}"

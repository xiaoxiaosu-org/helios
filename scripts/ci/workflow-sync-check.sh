#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"
source "${here}/_lib.sh"

backlog_file="docs/02-架构/执行计划/backlog.yaml"
changed_files_input="${1:-}"

if [ ! -f "${backlog_file}" ]; then
  echo "[workflow-sync] 缺少执行主文件：${backlog_file}" >&2
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

rule_file="$(mktemp)"
node -e '
const fs = require("node:fs");
const file = process.argv[1];
const data = JSON.parse(fs.readFileSync(file, "utf-8"));
for (const item of data.workItems || []) {
  if (!["debt", "task"].includes(String(item.kind || ""))) continue;
  if (String(item.status || "") === "done") continue;
  const wf = item.workflow || {};
  const trigger = (wf.triggerPaths || []).join(";");
  const required = (wf.requiredDocs || []).join(";");
  if (!trigger || !required) continue;
  process.stdout.write(`${item.workItemId}\t${trigger}\t${required}\n`);
}
' "${backlog_file}" > "${rule_file}"

if [ ! -s "${rule_file}" ]; then
  log "通过：无可执行规则，跳过 workflow-sync 检查"
  rm -f "${tmp_changed}" "${rule_file}"
  exit 0
fi

fail_file="$(mktemp)"
: > "${fail_file}"

while IFS=$'\t' read -r work_item_id trigger_paths required_docs; do
  [ -n "${work_item_id}" ] || continue

  triggered=0
  IFS=';' read -r -a trigger_arr <<< "${trigger_paths}"
  for p in "${trigger_arr[@]}"; do
    p="$(echo "${p}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "${p}" ] || continue
    if awk -v prefix="${p}" 'index($0, prefix) == 1 {found=1; exit} END{exit(found?0:1)}' "${tmp_changed}"; then
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
      echo "[workflow-sync] ${work_item_id} 触发了代码/门禁变更，但未同步必需文档。"
      echo "  - 触发路径: ${trigger_paths}"
      echo "  - 必需文档(至少一项): ${required_docs}"
    } >> "${fail_file}"
  fi
done < "${rule_file}"

if [ -s "${fail_file}" ]; then
  cat "${fail_file}" >&2
  rm -f "${tmp_changed}" "${rule_file}" "${fail_file}"
  exit 1
fi

log "通过：workflow-sync 文档联动检查通过"
rm -f "${tmp_changed}" "${rule_file}" "${fail_file}"

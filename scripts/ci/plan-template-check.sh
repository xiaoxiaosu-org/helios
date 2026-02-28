#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
source "${here}/_lib.sh"

ci_begin "计划模板一致性检查（plan-template-check）"

plan_dir="docs/02-架构/执行计划/active"
backlog_file="docs/02-架构/执行计划/backlog.yaml"
if [ ! -d "${plan_dir}" ]; then
  log "未检测到计划目录：${plan_dir}，跳过"
  exit 0
fi
if [ ! -f "${backlog_file}" ]; then
  echo "[plan-template] 缺少 backlog 主文件：${backlog_file}" >&2
  exit 1
fi

required_sections=(
  "## 背景与目标"
  "## WorkItem 清单"
  "## 推进记录"
  "## 验收与证据"
  "## 风险与阻塞"
  "## 下一步"
)

mapping_file="$(mktemp)"
: > "${mapping_file}"
failed=0

while IFS= read -r file; do
  [ -f "${file}" ] || continue
  base="$(basename "${file}")"
  plan_id="$(echo "${base}" | sed -nE 's/^(PLAN-[0-9]{8}-[0-9]{2}).*/\1/p')"

  if [ -z "${plan_id}" ]; then
    echo "[plan-template] ${file} 文件名必须以 PLAN-YYYYMMDD-NN 开头" >&2
    failed=1
    continue
  fi

  log "检查计划：${file}"

  for section in "${required_sections[@]}"; do
    if ! grep -Fx "${section}" "${file}" >/dev/null; then
      echo "[plan-template] ${file} 缺少必需段落：${section}" >&2
      failed=1
    fi
  done

  mapfile -t wi_ids < <(rg -o "WI-PLAN[0-9]{10}-[0-9]{2}" "${file}" | sort -u)
  if [ "${#wi_ids[@]}" -eq 0 ]; then
    echo "[plan-template] ${file} 未引用 WorkItem ID（WI-PLANYYYYMMDDNN-NN）" >&2
    failed=1
    continue
  fi

  expected_prefix="WI-${plan_id//-/}-"
  for wi in "${wi_ids[@]}"; do
    if [[ "${wi}" != ${expected_prefix}* ]]; then
      echo "[plan-template] ${file} 中 WorkItem ${wi} 不属于当前计划 ${plan_id}" >&2
      failed=1
    fi
    printf '%s\t%s\t%s\n' "${file}" "${plan_id}" "${wi}" >> "${mapping_file}"
  done
done < <(find "${plan_dir}" -maxdepth 1 -type f -name 'PLAN-*.md' | sort)

if [ "${failed}" -ne 0 ]; then
  rm -f "${mapping_file}"
  exit 1
fi

dup_wi="$(awk -F'\t' '{print $3}' "${mapping_file}" | sort | uniq -d | head -n 1 || true)"
if [ -n "${dup_wi}" ]; then
  echo "[plan-template] WorkItem 不能跨 plan 重复定义：${dup_wi}" >&2
  rm -f "${mapping_file}"
  exit 1
fi

node -e '
const fs = require("node:fs");
const backlogFile = process.argv[1];
const mappingFile = process.argv[2];
const backlog = JSON.parse(fs.readFileSync(backlogFile, "utf-8"));
const mappings = fs
  .readFileSync(mappingFile, "utf-8")
  .split(/\r?\n/)
  .filter(Boolean)
  .map((line) => {
    const [file, planId, wi] = line.split("\t");
    return { file, planId, wi };
  });

const itemByWi = new Map((backlog.workItems || []).map((item) => [String(item.workItemId || ""), item]));
const activePlanIds = new Set(mappings.map((m) => m.planId));
const mappedWi = new Set(mappings.map((m) => m.wi));
const errors = [];

for (const m of mappings) {
  const item = itemByWi.get(m.wi);
  if (!item) {
    errors.push(`[plan-template] ${m.file} 引用了 backlog 不存在的 WorkItem：${m.wi}`);
    continue;
  }
  if (String(item.planId || "") !== m.planId) {
    errors.push(`[plan-template] ${m.wi} 在 backlog 中归属 ${item.planId || "<empty>"}，与计划 ${m.planId} 不一致`);
  }
}

for (const item of backlog.workItems || []) {
  const planId = String(item.planId || "");
  const wi = String(item.workItemId || "");
  if (!activePlanIds.has(planId)) continue;
  if (!mappedWi.has(wi)) {
    errors.push(`[plan-template] backlog 中 ${wi}（${planId}）未出现在对应 active 计划文档`);
  }
}

if (errors.length > 0) {
  process.stderr.write(errors.join("\n") + "\n");
  process.exit(1);
}
' "${backlog_file}" "${mapping_file}"

rm -f "${mapping_file}"
log "通过：计划模板一致性检查通过"

#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const BACKLOG_REL = "docs/02-架构/执行计划/backlog.yaml";
const WI_RE = /^WI-PLAN\d{10}-\d{2}$/;
const PLAN_RE = /^PLAN-\d{8}-\d{2}$/;
const STATUS_SET = new Set(["todo", "in_progress", "blocked", "done"]);
const KIND_SET = new Set(["initiative", "capability", "task", "debt"]);

function usage() {
  console.error("用法：");
  console.error("  scripts/workflow/backlog-sync.mjs build");
  console.error("  scripts/workflow/backlog-sync.mjs check");
}

function resolveRepoRoot() {
  const currentFile = fileURLToPath(import.meta.url);
  const scriptDir = path.dirname(currentFile);
  return path.resolve(scriptDir, "..", "..");
}

function readBacklog(backlogFile) {
  if (!fs.existsSync(backlogFile)) {
    throw new Error(`缺少 backlog 文件：${BACKLOG_REL}`);
  }
  const raw = fs.readFileSync(backlogFile, "utf-8");
  return { raw, data: JSON.parse(raw) };
}

function ensureArray(value) {
  return Array.isArray(value) ? value : [];
}

function normalizeItem(item) {
  const next = { ...item };
  next.workItemId = String(item.workItemId || "").trim();
  next.planId = String(item.planId || "").trim();
  next.kind = String(item.kind || "").trim();
  next.status = String(item.status || "").trim();
  next.priority = String(item.priority || "").trim() || "P2";
  next.owner = String(item.owner || "").trim() || "repo-owner";
  next.title = String(item.title || "").trim();
  next.lastUpdate = String(item.lastUpdate || "").trim();

  if (typeof next.detail !== "object" || next.detail === null || Array.isArray(next.detail)) {
    next.detail = {};
  }

  const links = typeof next.links === "object" && next.links && !Array.isArray(next.links) ? next.links : {};
  next.links = {
    dependsOnWorkItems: ensureArray(links.dependsOnWorkItems).map(String).map((v) => v.trim()).filter(Boolean),
  };

  delete next.legacyId;

  const acceptance =
    typeof next.acceptance === "object" && next.acceptance && !Array.isArray(next.acceptance)
      ? next.acceptance
      : {};
  next.acceptance = {
    cmds: ensureArray(acceptance.cmds).map(String).map((v) => v.trim()).filter(Boolean),
    evidenceDir: String(acceptance.evidenceDir || "").trim(),
  };

  if (next.kind === "debt" || next.kind === "task") {
    const workflow =
      typeof next.workflow === "object" && next.workflow && !Array.isArray(next.workflow)
        ? next.workflow
        : {};
    next.workflow = {
      branchPrefix: String(workflow.branchPrefix || "").trim(),
      triggerPaths: ensureArray(workflow.triggerPaths).map(String).map((v) => v.trim()).filter(Boolean),
      requiredDocs: ensureArray(workflow.requiredDocs).map(String).map((v) => v.trim()).filter(Boolean),
      acceptanceCmds: ensureArray(workflow.acceptanceCmds)
        .map(String)
        .map((v) => v.trim())
        .filter(Boolean),
      closeChecks: String(workflow.closeChecks || "move_to_done=true,dependencies_done=false,adr_required=false").trim(),
    };
  } else {
    delete next.workflow;
  }

  const tracking =
    typeof next.tracking === "object" && next.tracking && !Array.isArray(next.tracking)
      ? next.tracking
      : {};
  const eventsFile = String(tracking.eventsFile || `artifacts/workflow/events/${next.workItemId}.jsonl`).trim();
  if (next.kind === "debt" || next.kind === "task") {
    next.tracking = { eventsFile };
  } else {
    delete next.tracking;
  }

  // 显式切断旧模型兼容字段。
  delete next.id;
  delete next.aliases;

  return next;
}

function computeSummary(workItems) {
  const statusCount = {
    todo: 0,
    in_progress: 0,
    blocked: 0,
    done: 0,
  };
  const kindCount = {
    initiative: 0,
    capability: 0,
    task: 0,
    debt: 0,
  };

  for (const item of workItems) {
    if (STATUS_SET.has(item.status)) {
      statusCount[item.status] += 1;
    }
    if (KIND_SET.has(item.kind)) {
      kindCount[item.kind] += 1;
    }
  }

  const planIds = new Set(workItems.map((item) => item.planId));
  return {
    workItemCount: workItems.length,
    planCount: planIds.size,
    statusCount,
    kindCount,
  };
}

function normalizeBacklog(input) {
  const backlog = { ...input };
  backlog.version = 3;

  const model =
    typeof backlog.model === "object" && backlog.model && !Array.isArray(backlog.model)
      ? backlog.model
      : {};
  backlog.model = {
    entity: "work_item",
    kinds: ["initiative", "capability", "task", "debt"],
    idPattern: "WI-PLANYYYYMMDDNN-NN",
    ownership: "single-plan-single-owner",
    note: String(model.note || "WorkItem 必须唯一归属一个 plan，不再兼容 TD/CAP 别名执行。"),
  };

  const sources =
    typeof backlog.sources === "object" && backlog.sources && !Array.isArray(backlog.sources)
      ? backlog.sources
      : {};
  backlog.sources = {
    executionSource: BACKLOG_REL,
    planDirectory: String(sources.planDirectory || "docs/02-架构/执行计划/active"),
    techDebtFile: String(sources.techDebtFile || "docs/02-架构/技术债清单.md"),
    adrIndexFile: String(sources.adrIndexFile || "docs/09-ADR-架构决策/ADR-索引.md"),
  };

  backlog.workItems = ensureArray(backlog.workItems)
    .map(normalizeItem)
    .sort((a, b) => {
      const p = a.planId.localeCompare(b.planId);
      if (p !== 0) return p;
      return a.workItemId.localeCompare(b.workItemId);
    });

  backlog.summary = computeSummary(backlog.workItems);
  return backlog;
}

function validateBacklog(backlog) {
  const errors = [];
  const byId = new Map();
  const allIds = new Set(backlog.workItems.map((item) => item.workItemId));

  for (const item of backlog.workItems) {
    if (!WI_RE.test(item.workItemId)) {
      errors.push(`[id-pattern] ${item.workItemId} 不符合 WI-PLANYYYYMMDDNN-NN`);
    }
    if (!PLAN_RE.test(item.planId)) {
      errors.push(`[plan-id] ${item.workItemId} 的 planId 非法：${item.planId}`);
    } else {
      const expectedPrefix = `WI-${item.planId.replace(/-/g, "")}-`;
      if (!item.workItemId.startsWith(expectedPrefix)) {
        errors.push(`[ownership] ${item.workItemId} 与 planId=${item.planId} 不匹配（期望前缀 ${expectedPrefix}）`);
      }
    }

    if (byId.has(item.workItemId)) {
      errors.push(`[duplicate] workItemId 重复：${item.workItemId}`);
    }
    byId.set(item.workItemId, item);

    if (!KIND_SET.has(item.kind)) {
      errors.push(`[kind] ${item.workItemId} kind 非法：${item.kind}`);
    }
    if (!STATUS_SET.has(item.status)) {
      errors.push(`[status] ${item.workItemId} status 非法：${item.status}`);
    }
    if (!item.title) {
      errors.push(`[title] ${item.workItemId} title 不能为空`);
    }
    if (!item.owner) {
      errors.push(`[owner] ${item.workItemId} owner 不能为空`);
    }

    for (const dep of item.links?.dependsOnWorkItems || []) {
      if (!allIds.has(dep)) {
        errors.push(`[depends-on] ${item.workItemId} 依赖不存在：${dep}`);
      }
    }

    if (Object.prototype.hasOwnProperty.call(item, "id") || Object.prototype.hasOwnProperty.call(item, "aliases")) {
      errors.push(`[legacy] ${item.workItemId} 仍包含旧字段 id/aliases，已禁止兼容`);
    }
  }

  if (errors.length > 0) {
    throw new Error(errors.join("\n"));
  }
}

function renderBacklog(backlog) {
  return `${JSON.stringify(backlog, null, 2)}\n`;
}

function buildBacklog(repoRoot) {
  const backlogFile = path.join(repoRoot, BACKLOG_REL);
  const { data } = readBacklog(backlogFile);
  const normalized = normalizeBacklog(data);
  validateBacklog(normalized);
  fs.writeFileSync(backlogFile, renderBacklog(normalized), "utf-8");
  console.log(`[backlog-sync] 已规范化：${BACKLOG_REL}`);
  console.log(`[backlog-sync] workItems=${normalized.summary.workItemCount}`);
}

function checkBacklog(repoRoot) {
  const backlogFile = path.join(repoRoot, BACKLOG_REL);
  const { raw, data } = readBacklog(backlogFile);
  const normalized = normalizeBacklog(data);
  validateBacklog(normalized);
  const expected = renderBacklog(normalized);

  if (raw !== expected) {
    console.error("[backlog-sync] backlog.yaml 非规范形式，请执行：scripts/workflow/backlog-sync.mjs build");
    process.exit(1);
  }
  console.log("[backlog-sync] 校验通过");
}

function main() {
  const repoRoot = resolveRepoRoot();
  const command = process.argv[2] || "build";

  if (command === "build") {
    buildBacklog(repoRoot);
    return;
  }
  if (command === "check") {
    checkBacklog(repoRoot);
    return;
  }

  usage();
  process.exit(1);
}

main();

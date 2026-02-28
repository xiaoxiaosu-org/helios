#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { buildStatus, resolveRepoRoot } from "./overview.mjs";

const BACKLOG_REL = "docs/02-架构/执行计划/backlog.yaml";

function usage() {
  console.error("用法：");
  console.error("  scripts/workflow/backlog-sync.mjs build");
  console.error("  scripts/workflow/backlog-sync.mjs check");
}

function debtDetailsFromStatus(status) {
  const openMap = new Map((status.td?.open || []).map((row) => [row.id, row]));
  const doneMap = new Map((status.td?.done || []).map((row) => [row.id, row]));
  return { openMap, doneMap };
}

function capDetailsFromStatus(status) {
  return new Map((status.caps || []).map((row) => [row.id, row]));
}

function toBacklog(status) {
  const { openMap, doneMap } = debtDetailsFromStatus(status);
  const capMap = capDetailsFromStatus(status);

  const workItems = (status.workItems || [])
    .map((item) => {
      if (item.kind === "debt") {
        const open = openMap.get(item.id);
        if (open) {
          return {
            id: item.id,
            kind: "debt",
            title: open.title,
            status: open.status,
            priority: open.priority,
            lastUpdate: open.lastUpdate,
            detail: {
              impact: open.impact,
              acceptance: open.acceptance,
              note: open.note,
            },
            links: {
              capabilityIds: item.links?.capabilityIds || [],
            },
            workflow: {
              branchPrefix: open.branchPrefix || "-",
              triggerPaths: open.triggerPaths || [],
              requiredDocs: open.requiredDocs || [],
              acceptanceCmds: open.acceptanceCmds || [],
            },
          };
        }

        const done = doneMap.get(item.id);
        return {
          id: item.id,
          kind: "debt",
          title: done?.title || item.title,
          status: "Done",
          priority: "-",
          lastUpdate: done?.doneDate || item.lastUpdate || "-",
          detail: {
            doneDate: done?.doneDate || "-",
            result: done?.result || "-",
          },
          links: {
            capabilityIds: item.links?.capabilityIds || [],
          },
        };
      }

      const cap = capMap.get(item.id);
      return {
        id: item.id,
        kind: "capability",
        title: cap?.ability || item.title,
        status: cap?.status || item.status,
        priority: item.priority || "P2",
        lastUpdate: "-",
        detail: {
          gap: cap?.gap || "-",
          deliverable: cap?.deliverable || "-",
          dod: cap?.dod || "-",
        },
        links: {
          debtIds: item.links?.debtIds || [],
        },
      };
    })
    .sort((a, b) => {
      if (a.kind !== b.kind) {
        return a.kind.localeCompare(b.kind);
      }
      return a.id.localeCompare(b.id);
    });

  const debtItems = workItems.filter((item) => item.kind === "debt");
  const capItems = workItems.filter((item) => item.kind === "capability");
  const debtDoneCount = debtItems.filter((item) => item.status === "Done").length;
  const capDoneCount = capItems.filter((item) => item.status === "Done").length;

  return {
    version: 1,
    model: {
      entity: "work_item",
      kinds: ["debt", "capability"],
      note: "TD 是 debt 的编号，CAP 是 capability；统一在 WorkItem 语义下管理。",
      mode: "transitional-sync-from-legacy",
    },
    sources: {
      workflowMap: status.sources.workflowMap,
      techDebtFile: status.sources.techDebtFile,
      planFile: status.sources.planFile,
      adrIndexFile: status.sources.adrIndexFile,
    },
    summary: {
      workItemCount: workItems.length,
      debtCount: debtItems.length,
      debtDoneCount,
      debtOpenCount: debtItems.length - debtDoneCount,
      capabilityCount: capItems.length,
      capabilityDoneCount: capDoneCount,
      capabilityPendingCount: capItems.length - capDoneCount,
    },
    workItems,
  };
}

function renderBacklog(backlog) {
  return `${JSON.stringify(backlog, null, 2)}\n`;
}

function buildBacklog(repoRoot) {
  const status = buildStatus(repoRoot);
  const backlog = toBacklog(status);
  const rendered = renderBacklog(backlog);
  const backlogFile = path.join(repoRoot, BACKLOG_REL);
  fs.mkdirSync(path.dirname(backlogFile), { recursive: true });
  fs.writeFileSync(backlogFile, rendered, "utf-8");
  console.log(`[backlog-sync] 已更新：${BACKLOG_REL}`);
  console.log(`[backlog-sync] workItems=${backlog.workItems.length}`);
}

function checkBacklog(repoRoot) {
  const status = buildStatus(repoRoot);
  const expected = renderBacklog(toBacklog(status));
  const backlogFile = path.join(repoRoot, BACKLOG_REL);
  if (!fs.existsSync(backlogFile)) {
    console.error(`[backlog-sync] 缺少文件：${BACKLOG_REL}`);
    process.exit(1);
  }
  const current = fs.readFileSync(backlogFile, "utf-8");
  if (current !== expected) {
    console.error("[backlog-sync] backlog.yaml 已过期，请执行：scripts/workflow/backlog-sync.mjs build");
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

#!/usr/bin/env node
/**
 * HELIOS 仓库统一总览入口（单一数据源聚合 + 本地看板服务）。
 */

import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";

const TD_ID_RE = /^TD-\d{3}$/;
const CAP_ID_RE = /^CAP-\d{3}$/;

function isoNow() {
  return new Date().toISOString();
}

function trim(value) {
  return String(value ?? "").trim();
}

function splitSemicolon(value) {
  return String(value ?? "")
    .split(";")
    .map((item) => item.trim())
    .filter(Boolean);
}

function runCmd(repoRoot, args) {
  const proc = spawnSync(args[0], args.slice(1), {
    cwd: repoRoot,
    encoding: "utf-8",
  });
  return {
    code: typeof proc.status === "number" ? proc.status : 1,
    stdout: proc.stdout ?? "",
    stderr: proc.stderr ?? "",
  };
}

function readText(filePath) {
  return fs.readFileSync(filePath, "utf-8");
}

function parseWorkflowMap(mapFile) {
  const meta = {};
  const workflows = {};

  if (!fs.existsSync(mapFile)) {
    return { meta, workflows };
  }

  const lines = readText(mapFile).split(/\r?\n/);
  let section = "";
  let current = null;

  for (const raw of lines) {
    const stripped = raw.trim();
    if (!stripped || stripped.startsWith("#")) {
      continue;
    }

    if (stripped === "meta:") {
      section = "meta";
      current = null;
      continue;
    }
    if (stripped === "workflows:") {
      section = "workflows";
      current = null;
      continue;
    }

    if (section === "meta") {
      const match = stripped.match(/^([a-zA-Z0-9_]+):\s*(.+)$/);
      if (match) {
        meta[match[1]] = match[2].trim().replace(/^['"]|['"]$/g, "");
      }
      continue;
    }

    if (section !== "workflows") {
      continue;
    }

    const tdMatch = stripped.match(/^-\s*td_id:\s*(TD-\d{3})\s*$/);
    if (tdMatch) {
      current = { td_id: tdMatch[1] };
      workflows[tdMatch[1]] = current;
      continue;
    }

    if (!current) {
      continue;
    }

    const fieldMatch = stripped.match(/^([a-zA-Z0-9_]+):\s*(.*)$/);
    if (fieldMatch) {
      current[fieldMatch[1]] = fieldMatch[2].trim().replace(/^['"]|['"]$/g, "");
    }
  }

  return { meta, workflows };
}

function splitMarkdownRow(line) {
  const row = line.trim().replace(/^\|/, "").replace(/\|$/, "");
  return row.split("|").map((cell) => trim(cell));
}

function parseTechDebt(techDebtFile) {
  const openRows = [];
  const doneRows = [];
  let section = "";

  if (!fs.existsSync(techDebtFile)) {
    return { openRows, doneRows };
  }

  const lines = readText(techDebtFile).split(/\r?\n/);
  for (const line of lines) {
    if (line.startsWith("## 在制技术债")) {
      section = "open";
      continue;
    }
    if (line.startsWith("## 已完成")) {
      section = "done";
      continue;
    }
    if (!line.startsWith("| TD-")) {
      continue;
    }

    const cols = splitMarkdownRow(line);
    if (section === "open" && cols.length >= 8) {
      openRows.push({
        id: cols[0],
        title: cols[1],
        impact: cols[2],
        priority: cols[3],
        acceptance: cols[4],
        status: cols[5],
        lastUpdate: cols[6],
        note: cols[7] || "-",
      });
      continue;
    }

    if (section === "done" && cols.length >= 4) {
      doneRows.push({
        id: cols[0],
        title: cols[1],
        doneDate: cols[2],
        result: cols[3],
      });
    }
  }

  return { openRows, doneRows };
}

function parseCapPlan(planFile) {
  const caps = {};
  if (!fs.existsSync(planFile)) {
    return caps;
  }

  const lines = readText(planFile).split(/\r?\n/);
  for (const line of lines) {
    if (!line.startsWith("| CAP-")) {
      continue;
    }
    const cols = splitMarkdownRow(line);
    if (cols.length < 6) {
      continue;
    }
    const capId = cols[0];
    if (!CAP_ID_RE.test(capId)) {
      continue;
    }
    caps[capId] = {
      id: capId,
      ability: cols[1],
      gap: cols[2],
      deliverable: cols[3],
      dod: cols[4],
      status: cols[5],
    };
  }
  return caps;
}

function parseGitState(repoRoot) {
  const branchResult = runCmd(repoRoot, ["git", "status", "--porcelain=v1", "--branch"]);
  let branch = "unknown";
  let ahead = 0;
  let behind = 0;
  const changed = [];

  if (branchResult.code === 0 && branchResult.stdout) {
    const lines = branchResult.stdout.split(/\r?\n/).filter((line) => line.length > 0);
    if (lines.length > 0) {
      const header = lines[0];
      const branchMatch = header.match(/^##\s+([^\s.]+)/);
      if (branchMatch) {
        branch = branchMatch[1];
      }
      const aheadMatch = header.match(/ahead (\d+)/);
      if (aheadMatch) {
        ahead = Number(aheadMatch[1]);
      }
      const behindMatch = header.match(/behind (\d+)/);
      if (behindMatch) {
        behind = Number(behindMatch[1]);
      }
    }
    for (const line of lines.slice(1)) {
      if (line.length < 4) {
        continue;
      }
      const status = line.slice(0, 2).trim() || "??";
      let filePath = line.slice(3);
      if (filePath.includes(" -> ")) {
        filePath = filePath.split(" -> ", 2)[1];
      }
      changed.push({ status, path: filePath });
    }
  }

  const headResult = runCmd(repoRoot, ["git", "rev-parse", "--short", "HEAD"]);
  const head = headResult.code === 0 ? trim(headResult.stdout) : "unknown";

  return {
    branch,
    head,
    ahead,
    behind,
    isDirty: changed.length > 0,
    changedFiles: changed,
    changedCount: changed.length,
  };
}

function readLatestWorkflowRun(repoRoot, tdId) {
  const tdDir = path.join(repoRoot, "artifacts", "workflow", tdId);
  if (!fs.existsSync(tdDir) || !fs.statSync(tdDir).isDirectory()) {
    return null;
  }

  const runDirs = fs
    .readdirSync(tdDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort((a, b) => b.localeCompare(a));
  if (runDirs.length === 0) {
    return null;
  }

  const runId = runDirs[0];
  const runDir = path.join(tdDir, runId);
  const closeReport = path.join(runDir, "close-report.txt");
  const progressReport = path.join(runDir, "progress-report.txt");

  let reportType = "none";
  let reportFile = "";
  let status = "unknown";
  let summary = "无报告";

  if (fs.existsSync(closeReport)) {
    reportType = "close";
    reportFile = path.relative(repoRoot, closeReport);
    const content = readText(closeReport);
    if (content.includes("Result: PASS")) {
      status = "PASS";
      summary = "闭环通过";
    } else {
      status = "FAIL";
      summary = "闭环失败";
    }
  } else if (fs.existsSync(progressReport)) {
    reportType = "progress";
    reportFile = path.relative(repoRoot, progressReport);
    const content = readText(progressReport);
    if (content.includes("失败用例：0")) {
      status = "PASS";
      summary = "推进通过";
    } else {
      status = "FAIL";
      summary = "推进失败";
    }
  }

  return {
    runId,
    reportType,
    reportFile,
    status,
    summary,
  };
}

function normalizePriority(priority) {
  const match = trim(priority).match(/^P(\d+)$/);
  if (!match) {
    return 99;
  }
  return Number(match[1]);
}

function listExperienceDocs(repoRoot) {
  const expDir = path.join(repoRoot, "docs/02-架构/工程治理/经验库");
  if (!fs.existsSync(expDir) || !fs.statSync(expDir).isDirectory()) {
    return [];
  }

  return fs
    .readdirSync(expDir)
    .filter((name) => name.endsWith(".md"))
    .sort()
    .map((name) => {
      const filePath = path.join(expDir, name);
      const content = readText(filePath);
      const titleLine = content
        .split(/\r?\n/)
        .find((line) => line.trim().startsWith("# "));
      const title = titleLine ? titleLine.replace(/^#\s+/, "").trim() : name;
      return {
        path: path.relative(repoRoot, filePath),
        title,
        type: name === "README.md" ? "index" : "experience",
      };
    });
}

function readDocModuleStatuses(repoRoot) {
  const statusDir = path.join(repoRoot, "artifacts/ci/doc-library/module-status");
  const map = {};
  if (!fs.existsSync(statusDir) || !fs.statSync(statusDir).isDirectory()) {
    return map;
  }

  const files = fs.readdirSync(statusDir).filter((name) => name.endsWith(".json"));
  for (const name of files) {
    const filePath = path.join(statusDir, name);
    try {
      const parsed = JSON.parse(readText(filePath));
      const moduleId = trim(parsed.module) || name.replace(/\.json$/, "");
      map[moduleId] = {
        module: moduleId,
        status: trim(parsed.status) || "UNKNOWN",
        ok: Boolean(parsed.ok),
        startedAt: trim(parsed.startedAt) || "",
        endedAt: trim(parsed.endedAt) || "",
        outDir: trim(parsed.outDir) || "",
      };
    } catch {
      map[name.replace(/\.json$/, "")] = {
        module: name.replace(/\.json$/, ""),
        status: "UNKNOWN",
        ok: false,
        startedAt: "",
        endedAt: "",
        outDir: "",
      };
    }
  }
  return map;
}

function countMarkdownFilesRecursively(dirPath) {
  if (!fs.existsSync(dirPath) || !fs.statSync(dirPath).isDirectory()) {
    return 0;
  }

  let count = 0;
  const stack = [dirPath];
  while (stack.length > 0) {
    const current = stack.pop();
    const entries = fs.readdirSync(current, { withFileTypes: true });
    for (const entry of entries) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(full);
        continue;
      }
      if (entry.isFile() && entry.name.endsWith(".md")) {
        count += 1;
      }
    }
  }
  return count;
}

function countImmediateSubIndexes(dirPath) {
  if (!fs.existsSync(dirPath) || !fs.statSync(dirPath).isDirectory()) {
    return 0;
  }
  const entries = fs.readdirSync(dirPath, { withFileTypes: true });
  let count = 0;
  for (const entry of entries) {
    if (!entry.isDirectory()) {
      continue;
    }
    const readmeFile = path.join(dirPath, entry.name, "README.md");
    if (fs.existsSync(readmeFile)) {
      count += 1;
    }
  }
  return count;
}

function buildDocsStructure(repoRoot, options) {
  const docsRoot = path.join(repoRoot, "docs");
  const domains = [];
  if (fs.existsSync(docsRoot) && fs.statSync(docsRoot).isDirectory()) {
    const entries = fs
      .readdirSync(docsRoot, { withFileTypes: true })
      .filter((entry) => entry.isDirectory() && /^\d{2}-/.test(entry.name))
      .sort((a, b) => a.name.localeCompare(b.name));

    for (const entry of entries) {
      const domainPath = path.join(docsRoot, entry.name);
      const relPath = path.relative(repoRoot, domainPath);
      const domainName = entry.name.includes("-") ? entry.name.split("-").slice(1).join("-") : entry.name;
      const readmePath = path.join(domainPath, "README.md");
      domains.push({
        id: entry.name,
        name: domainName,
        path: relPath,
        hasReadme: fs.existsSync(readmePath),
        markdownCount: countMarkdownFilesRecursively(domainPath),
        subIndexCount: countImmediateSubIndexes(domainPath),
      });
    }
  }

  const keyFiles = [
    { id: "docs_root", title: "docs 总导航", path: "docs/README.md" },
    { id: "workflow_map", title: "workflow map", path: options.workflowMapRel },
    { id: "backlog", title: "WorkItem 主文件", path: options.backlogFileRel },
    { id: "tech_debt", title: "技术债清单", path: options.techDebtRel },
    { id: "plan", title: "执行计划", path: options.planRel },
    { id: "exp_index", title: "经验库索引", path: "docs/02-架构/工程治理/经验库/README.md" },
  ].map((item) => ({
    ...item,
    exists: fs.existsSync(path.join(repoRoot, item.path)),
  }));

  const indexedCount = domains.filter((domain) => domain.hasReadme).length;
  const keyFilePassCount = keyFiles.filter((item) => item.exists).length;

  return {
    domains,
    keyFiles,
    summary: {
      domainCount: domains.length,
      indexedDomainCount: indexedCount,
      keyFileCount: keyFiles.length,
      keyFilePassCount,
      experienceDocCount: options.experienceDocCount,
    },
  };
}

function buildDocRuleCatalog(docModuleStatuses) {
  const moduleStatus = (id) => docModuleStatuses[id] || null;
  const rules = [
    {
      id: "internal-index",
      scope: "internal",
      title: "索引结构一致性",
      description: "校验 docs/README 与分域索引入口完整性。",
      source: "scripts/docs/index-check.sh",
      action: "docs.library.index",
      status: moduleStatus("index"),
    },
    {
      id: "internal-rules",
      scope: "internal",
      title: "规则文件一致性",
      description: "校验规则文档格式、语言与关键内容约束。",
      source: "scripts/docs/rule-files-check.sh",
      action: "docs.library.rules",
      status: moduleStatus("rules"),
    },
    {
      id: "internal-governance",
      scope: "internal",
      title: "治理文档同步",
      description: "校验 Hook/Workflow/模板/治理文档一致性。",
      source: "scripts/docs/git-governance-sync-check.sh",
      action: "docs.library.governance",
      status: moduleStatus("governance"),
    },
    {
      id: "internal-gardening",
      scope: "internal",
      title: "文档除草检查",
      description: "校验死链、过期入口与文档可维护性。",
      source: "scripts/docs/gardening.sh",
      action: "docs.library.gardening",
      status: moduleStatus("gardening"),
    },
    {
      id: "internal-all",
      scope: "internal",
      title: "内部规则全量回归",
      description: "一次执行全部文档库内部校验模块。",
      source: "scripts/docs/library-check.sh all",
      action: "docs.library.all",
      status: moduleStatus("all"),
    },
    {
      id: "external-doc-check",
      scope: "external",
      title: "外部 CI 对齐：doc-check",
      description: "对应 .github/workflows/doc-check.yml 的本地等价检查入口。",
      source: ".github/workflows/doc-check.yml",
      action: "docs.library.all",
      status: moduleStatus("all"),
    },
    {
      id: "external-workflow-sync",
      scope: "external",
      title: "外部 CI 对齐：workflow-sync",
      description: "对应 quality-gates 的文档联动门禁。",
      source: "scripts/ci/workflow-sync-check.sh",
      action: "ci.workflow_sync",
      status: null,
    },
    {
      id: "external-tech-debt",
      scope: "external",
      title: "外部 CI 对齐：技术债治理",
      description: "对应 quality-gates 的技术债治理门禁。",
      source: "scripts/ci/tech-debt-governance-check.sh",
      action: "ci.tech_debt",
      status: null,
    },
    {
      id: "external-quality-gates",
      scope: "external",
      title: "外部 CI 对齐：quality-gates",
      description: "执行本地聚合门禁，覆盖 quality-gates 关键检查。",
      source: ".github/workflows/quality-gates.yml",
      action: "ci.verify",
      status: null,
    },
  ];

  return {
    internal: rules.filter((item) => item.scope === "internal"),
    external: rules.filter((item) => item.scope === "external"),
    all: rules,
  };
}

function buildStatus(repoRoot) {
  const mapFile = path.join(repoRoot, "docs/02-架构/执行计划/workflow-map.yaml");
  const backlogFileRel = "docs/02-架构/执行计划/backlog.yaml";
  const { meta, workflows } = parseWorkflowMap(mapFile);

  const techDebtRel = meta.tech_debt_file || "docs/02-架构/技术债清单.md";
  const planRel =
    meta.plan_file || "docs/02-架构/执行计划/active/PLAN-20260227-工程智能化路线图.md";
  const adrIndexRel = meta.adr_index_file || "docs/09-ADR-架构决策/ADR-索引.md";

  const techDebtFile = path.join(repoRoot, techDebtRel);
  const planFile = path.join(repoRoot, planRel);
  const { openRows: openTd, doneRows: doneTd } = parseTechDebt(techDebtFile);
  const caps = parseCapPlan(planFile);
  const gitState = parseGitState(repoRoot);

  const capToTd = {};
  for (const [tdId, record] of Object.entries(workflows)) {
    const capId = record.cap_id || "";
    if (CAP_ID_RE.test(capId)) {
      capToTd[capId] = tdId;
    }
  }

  const tdOpenEnriched = [];
  const tdDoneEnriched = [];
  const pendingTasks = [];
  const repoTasks = [];

  for (const row of openTd) {
    const tdId = row.id;
    const wf = workflows[tdId] || {};
    const capId = wf.cap_id || "";
    const capStatus = (caps[capId] || {}).status || "Unknown";
    const latestRun = readLatestWorkflowRun(repoRoot, tdId);
    const acceptanceCmds = splitSemicolon(wf.acceptance_cmds || "");
    const requiredDocs = splitSemicolon(wf.required_docs || "");

    tdOpenEnriched.push({
      ...row,
      capId: capId || "-",
      capStatus,
      branchPrefix: wf.branch_prefix || "-",
      triggerPaths: splitSemicolon(wf.trigger_paths || ""),
      requiredDocs,
      acceptanceCmds,
      latestRun,
    });

    const priorityNum = normalizePriority(row.priority || "P99");
    if (row.status === "Open") {
      pendingTasks.push({
        id: `${tdId}-start`,
        title: `启动 ${tdId}`,
        type: "workflow",
        priority: row.priority || "P99",
        priorityRank: priorityNum,
        relatedTd: tdId,
        relatedCap: capId,
        command: `scripts/workflow/start.sh ${tdId}`,
        action: "workflow.start",
        params: { tdId },
        reason: "状态为 Open，需要先启动工作流。",
      });
    } else if (acceptanceCmds.length === 0) {
      pendingTasks.push({
        id: `${tdId}-progress`,
        title: `推进 ${tdId}`,
        type: "workflow",
        priority: row.priority || "P99",
        priorityRank: priorityNum,
        relatedTd: tdId,
        relatedCap: capId,
        command: `scripts/workflow/progress.sh ${tdId}`,
        action: "workflow.progress",
        params: { tdId },
        reason: "在制项需要持续执行验收命令并更新状态。",
      });
    }

    pendingTasks.push({
      id: `${tdId}-close`,
      title: `尝试闭环 ${tdId}`,
      type: "workflow",
      priority: row.priority || "P99",
      priorityRank: priorityNum,
      relatedTd: tdId,
      relatedCap: capId,
      command: `scripts/workflow/close.sh ${tdId}`,
      action: "workflow.close",
      params: { tdId },
      reason: "闭环会校验必需文档、CAP 状态与 ADR 要求。",
    });

    if (acceptanceCmds.length > 0) {
      pendingTasks.push({
        id: `${tdId}-acceptance-task`,
        title: `执行 ${tdId} 验收任务`,
        type: "acceptance",
        priority: row.priority || "P99",
        priorityRank: priorityNum,
        relatedTd: tdId,
        relatedCap: capId,
        command: `scripts/workflow/progress.sh ${tdId}`,
        action: "workflow.progress",
        params: { tdId },
        reason: `任务包含 ${acceptanceCmds.length} 条验收命令（详情见 TD 配置）。`,
      });
    }

    if (capId && capStatus !== "Done") {
      pendingTasks.push({
        id: `${tdId}-cap-state`,
        title: `${capId} 尚未 Done`,
        type: "cap",
        priority: row.priority || "P99",
        priorityRank: priorityNum,
        relatedTd: tdId,
        relatedCap: capId,
        command: `更新 ${planRel} 中 ${capId} 状态并补充证据`,
        action: "command.copy_only",
        params: { command: `编辑 ${planRel}，推进 ${capId} 至 Done` },
        reason: "TD 闭环依赖 CAP 状态满足路线图约束。",
      });
    }
  }

  for (const row of doneTd) {
    const wf = workflows[row.id] || {};
    tdDoneEnriched.push({
      ...row,
      capId: wf.cap_id || "-",
    });
  }

  const capRows = Object.keys(caps)
    .sort()
    .map((capId) => {
      const cap = caps[capId];
      const tdId = capToTd[capId] || "-";
      const isPending = cap.status !== "Done";
      if (isPending) {
        pendingTasks.push({
          id: `${capId}-plan`,
          title: `推进 ${capId}`,
          type: "cap",
          priority: "P2",
          priorityRank: 2,
          relatedTd: tdId,
          relatedCap: capId,
          command: `scripts/cap/verify.sh ${capId}`,
          action: "cap.verify",
          params: { capId },
          reason: "路线图状态尚未 Done。",
        });
      }
      return {
        ...cap,
        tdId,
        isPending,
      };
    });

  if (gitState.isDirty) {
    repoTasks.push({
      id: "repo-verify",
      title: "执行门禁聚合校验",
      type: "repo",
      priority: "P1",
      priorityRank: 1,
      relatedTd: "-",
      relatedCap: "-",
      command: "scripts/ci/verify.sh",
      action: "ci.verify",
      params: {},
      reason: "工作区存在改动，提交前应执行统一门禁。",
    });
  }

  pendingTasks.sort((a, b) => {
    const ar = a.priorityRank ?? 99;
    const br = b.priorityRank ?? 99;
    if (ar !== br) {
      return ar - br;
    }
    const at = a.relatedTd ?? "";
    const bt = b.relatedTd ?? "";
    if (at !== bt) {
      return at.localeCompare(bt);
    }
    return String(a.id ?? "").localeCompare(String(b.id ?? ""));
  });

  const tdBlockedCount = openTd.filter((row) => row.status === "Blocked").length;
  const capDoneCount = capRows.filter((row) => row.status === "Done").length;
  const experienceDocs = listExperienceDocs(repoRoot);
  const docModuleStatuses = readDocModuleStatuses(repoRoot);
  const docsStructure = buildDocsStructure(repoRoot, {
    workflowMapRel: path.relative(repoRoot, mapFile),
    backlogFileRel,
    techDebtRel,
    planRel,
    experienceDocCount: experienceDocs.filter((doc) => doc.type === "experience").length,
  });
  const docRuleCatalog = buildDocRuleCatalog(docModuleStatuses);
  const docModules = [
    { id: "all", title: "全部校验与统一", action: "docs.library.all" },
    { id: "index", title: "索引结构", action: "docs.library.index" },
    { id: "rules", title: "规则文档", action: "docs.library.rules" },
    { id: "governance", title: "治理一致性", action: "docs.library.governance" },
    { id: "gardening", title: "文档除草", action: "docs.library.gardening" },
  ].map((module) => ({
    ...module,
    lastRun: docModuleStatuses[module.id] || null,
  }));
  const workItems = [
    ...tdOpenEnriched.map((row) => ({
      id: row.id,
      kind: "debt",
      status: row.status,
      title: row.title,
      priority: row.priority,
      lastUpdate: row.lastUpdate,
      links: {
        capabilityIds: row.capId && row.capId !== "-" ? [row.capId] : [],
      },
    })),
    ...tdDoneEnriched.map((row) => ({
      id: row.id,
      kind: "debt",
      status: "Done",
      title: row.title,
      priority: "-",
      lastUpdate: row.doneDate,
      links: {
        capabilityIds: row.capId && row.capId !== "-" ? [row.capId] : [],
      },
    })),
    ...capRows.map((row) => ({
      id: row.id,
      kind: "capability",
      status: row.status,
      title: row.ability,
      priority: row.status === "Done" ? "-" : "P2",
      lastUpdate: "-",
      links: {
        debtIds: row.tdId && row.tdId !== "-" ? [row.tdId] : [],
      },
    })),
  ];

  return {
    generatedAt: isoNow(),
    sources: {
      workflowMap: path.relative(repoRoot, mapFile),
      techDebtFile: techDebtRel,
      planFile: planRel,
      adrIndexFile: adrIndexRel,
      backlogFile: backlogFileRel,
    },
    model: {
      entity: "work_item",
      kinds: ["debt", "capability"],
      note: "TD 是 debt 的编号，不是独立语义类型；CAP 是 capability。",
    },
    repo: {
      root: repoRoot,
      ...gitState,
    },
    summary: {
      tdOpenCount: openTd.length,
      tdDoneCount: doneTd.length,
      tdBlockedCount,
      capTotalCount: capRows.length,
      capDoneCount,
      capPendingCount: capRows.length - capDoneCount,
      todoTaskCount: pendingTasks.length + repoTasks.length,
      pendingTaskCount: pendingTasks.length,
      repoTaskCount: repoTasks.length,
      docRuleCount: docRuleCatalog.all.length,
      dirtyFileCount: gitState.changedCount,
    },
    docsLibrary: {
      modules: docModules,
    },
    experienceLibrary: {
      checkAction: "docs.library.experience",
      checkTitle: "经验库规则校验",
      lastRun: docModuleStatuses.experience || null,
      docs: experienceDocs,
    },
    docRules: docRuleCatalog,
    docsStructure,
    td: {
      open: tdOpenEnriched,
      done: tdDoneEnriched,
    },
    caps: capRows,
    pendingTasks,
    repoTasks,
    workItems,
  };
}

function executeAction(repoRoot, payload) {
  const action = trim(payload.action);
  const tdId = trim(payload.tdId);
  const capId = trim(payload.capId);
  const customCommand = trim(payload.command);

  let command = null;
  if (["workflow.start", "workflow.progress", "workflow.close", "workflow.full"].includes(action)) {
    if (!TD_ID_RE.test(tdId)) {
      throw new Error("tdId 非法，必须为 TD-XXX");
    }
    command = ["scripts/workflow/run.sh", tdId, action.split(".", 2)[1]];
  } else if (action === "ci.verify") {
    command = ["scripts/ci/verify.sh"];
  } else if (action === "docs.governance.verify") {
    command = ["scripts/docs/git-governance-sync-check.sh"];
  } else if (action === "ci.workflow_sync") {
    command = ["scripts/ci/workflow-sync-check.sh"];
  } else if (action === "ci.tech_debt") {
    command = ["scripts/ci/tech-debt-governance-check.sh", "--out", "artifacts/ci/tech-debt-governance"];
  } else if (action === "cap.verify") {
    if (!CAP_ID_RE.test(capId)) {
      throw new Error("capId 非法，必须为 CAP-XXX");
    }
    command = ["scripts/cap/verify.sh", capId];
  } else if (action === "docs.library.all") {
    command = ["scripts/docs/library-check.sh", "all"];
  } else if (action === "docs.library.index") {
    command = ["scripts/docs/library-check.sh", "index"];
  } else if (action === "docs.library.rules") {
    command = ["scripts/docs/library-check.sh", "rules"];
  } else if (action === "docs.library.experience") {
    command = ["scripts/docs/library-check.sh", "experience"];
  } else if (action === "docs.library.governance") {
    command = ["scripts/docs/library-check.sh", "governance"];
  } else if (action === "docs.library.gardening") {
    command = ["scripts/docs/library-check.sh", "gardening"];
  } else if (action === "command.copy_only") {
    throw new Error(`该任务仅支持复制命令执行：${customCommand}`);
  }

  if (!command) {
    throw new Error(`不支持的 action: ${action}`);
  }

  const startedAt = isoNow();
  const result = runCmd(repoRoot, command);
  const endedAt = isoNow();
  const maxLen = 16000;
  const stdout = result.stdout.slice(-maxLen);
  const stderr = result.stderr.slice(-maxLen);

  return {
    ok: result.code === 0,
    command,
    returnCode: result.code,
    stdout,
    stderr,
    startedAt,
    endedAt,
  };
}

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(body),
    "Cache-Control": "no-store",
  });
  res.end(body);
}

function sendText(res, statusCode, text, contentType = "text/plain; charset=utf-8") {
  const body = String(text);
  res.writeHead(statusCode, {
    "Content-Type": contentType,
    "Content-Length": Buffer.byteLength(body),
  });
  res.end(body);
}

function serve(repoRoot, host, port) {
  const uiFile = path.join(repoRoot, "scripts/workflow/dashboard/index.html");
  const server = http.createServer((req, res) => {
    const method = req.method || "GET";
    const url = req.url || "/";
    console.log(`[overview-http] ${method} ${url}`);

    if (method === "GET" && (url === "/" || url === "/index.html")) {
      if (!fs.existsSync(uiFile)) {
        sendText(res, 404, "缺少前端页面文件：scripts/workflow/dashboard/index.html");
        return;
      }
      sendText(res, 200, readText(uiFile), "text/html; charset=utf-8");
      return;
    }

    if (method === "GET" && url === "/api/health") {
      sendJson(res, 200, { ok: true, now: isoNow() });
      return;
    }

    if (method === "GET" && url === "/api/status") {
      try {
        sendJson(res, 200, buildStatus(repoRoot));
      } catch (error) {
        sendJson(res, 500, { ok: false, error: String(error?.message ?? error) });
      }
      return;
    }

    if (method === "POST" && url === "/api/action") {
      let body = "";
      req.on("data", (chunk) => {
        body += chunk.toString("utf-8");
        if (body.length > 1_000_000) {
          req.destroy(new Error("request body too large"));
        }
      });
      req.on("end", () => {
        let payload = {};
        try {
          payload = body ? JSON.parse(body) : {};
        } catch {
          sendJson(res, 400, { ok: false, error: "请求体不是合法 JSON" });
          return;
        }
        try {
          const result = executeAction(repoRoot, payload);
          sendJson(res, result.ok ? 200 : 409, result);
        } catch (error) {
          sendJson(res, 400, { ok: false, error: String(error?.message ?? error) });
        }
      });
      return;
    }

    sendText(res, 404, "Not Found");
  });

  server.on("error", (error) => {
    console.error(
      `[overview] 启动失败: ${error?.code || "UNKNOWN"} ${error?.message || String(error)}`
    );
    process.exit(1);
  });

  server.on("listening", () => {
    console.log(`[overview] repo=${repoRoot}`);
    console.log(`[overview] ui=${path.relative(repoRoot, uiFile)}`);
    console.log(`[overview] http://${host}:${port}`);
  });

  server.listen(port, host);
}

function parseNamedArgs(rawArgs) {
  const options = {};
  for (let i = 0; i < rawArgs.length; i += 1) {
    const token = rawArgs[i];
    if (!token.startsWith("--")) {
      continue;
    }
    const key = token.slice(2);
    const value = rawArgs[i + 1] && !rawArgs[i + 1].startsWith("--") ? rawArgs[++i] : "true";
    options[key] = value;
  }
  return options;
}

function commandJson(repoRoot, rawArgs) {
  const options = parseNamedArgs(rawArgs);
  const outFile = trim(options.out);
  const payload = buildStatus(repoRoot);
  const rendered = `${JSON.stringify(payload, null, 2)}\n`;
  if (outFile) {
    fs.mkdirSync(path.dirname(outFile), { recursive: true });
    fs.writeFileSync(outFile, rendered, "utf-8");
    console.log(path.resolve(outFile));
    return 0;
  }
  process.stdout.write(rendered);
  return 0;
}

function commandServe(repoRoot, rawArgs) {
  const options = parseNamedArgs(rawArgs);
  const host = trim(options.host) || "127.0.0.1";
  const portRaw = trim(options.port) || "8787";
  const port = Number(portRaw);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    console.error(`非法端口: ${portRaw}`);
    return 1;
  }
  serve(repoRoot, host, port);
  return 0;
}

function usage() {
  console.error("用法：");
  console.error("  scripts/workflow/overview.mjs json [--out <file>]");
  console.error("  scripts/workflow/overview.mjs serve [--host 127.0.0.1] [--port 8787]");
}

function resolveRepoRoot() {
  const currentFile = fileURLToPath(import.meta.url);
  const scriptDir = path.dirname(currentFile);
  return path.resolve(scriptDir, "..", "..");
}

function main() {
  const repoRoot = resolveRepoRoot();
  const [command = "", ...rest] = process.argv.slice(2);

  if (command === "json") {
    return commandJson(repoRoot, rest);
  }
  if (command === "serve") {
    return commandServe(repoRoot, rest);
  }
  usage();
  return 1;
}
export { buildStatus, resolveRepoRoot };

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = main();
}

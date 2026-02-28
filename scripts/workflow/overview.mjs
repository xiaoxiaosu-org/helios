#!/usr/bin/env node
/**
 * HELIOS 仓库统一总览入口（backlog 主模型）。
 */

import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";

const WORK_ITEM_ID_RE = /^WI-PLAN\d{10}-\d{2}$/;
const BACKLOG_REL = "docs/02-架构/执行计划/backlog.yaml";

function isoNow() {
  return new Date().toISOString();
}

function trim(value) {
  return String(value ?? "").trim();
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

function readBacklog(repoRoot) {
  const file = path.join(repoRoot, BACKLOG_REL);
  if (!fs.existsSync(file)) {
    throw new Error(`缺少 backlog 主文件：${BACKLOG_REL}`);
  }
  return JSON.parse(readText(file));
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
      const branchMatch = header.match(/^##\s+(.+?)(?:\.\.\.|$)/);
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
      if (line.length < 4) continue;
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

function readLatestWorkflowRun(repoRoot, workItemId) {
  const wiDir = path.join(repoRoot, "artifacts", "workflow", workItemId);
  if (!fs.existsSync(wiDir) || !fs.statSync(wiDir).isDirectory()) {
    return null;
  }

  const runDirs = fs
    .readdirSync(wiDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort((a, b) => b.localeCompare(a));
  if (runDirs.length === 0) {
    return null;
  }

  const runId = runDirs[0];
  const runDir = path.join(wiDir, runId);
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
    if (!entry.isDirectory()) continue;
    const readmeFile = path.join(dirPath, entry.name, "README.md");
    if (fs.existsSync(readmeFile)) count += 1;
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
    { id: "backlog", title: "WorkItem 主文件", path: BACKLOG_REL },
    { id: "workflow", title: "工作流手册", path: options.workflowGuideRel },
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
      id: "external-workflow-sync",
      scope: "external",
      title: "外部 CI 对齐：workflow-sync",
      description: "对应 quality-gates 的文档联动门禁。",
      source: "scripts/ci/workflow-sync-check.sh",
      action: "ci.workflow_sync",
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

function resolvePrimaryPlanRel(repoRoot, planId) {
  const activeDirRel = "docs/02-架构/执行计划/active";
  const activeDir = path.join(repoRoot, activeDirRel);
  if (!fs.existsSync(activeDir) || !fs.statSync(activeDir).isDirectory()) {
    return `${activeDirRel}/PLAN-20260227-01-工程智能化路线图.md`;
  }
  const entries = fs
    .readdirSync(activeDir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.startsWith("PLAN-") && entry.name.endsWith(".md"))
    .map((entry) => entry.name)
    .sort();
  if (entries.length === 0) {
    return `${activeDirRel}/PLAN-20260227-01-工程智能化路线图.md`;
  }
  if (planId) {
    const matched = entries.find((name) => name.startsWith(`${planId}-`));
    if (matched) return `${activeDirRel}/${matched}`;
  }
  return `${activeDirRel}/${entries[0]}`;
}

function normalizePriority(priority) {
  const match = trim(priority).match(/^P(\d+)$/);
  if (!match) return 99;
  return Number(match[1]);
}

function buildStatus(repoRoot) {
  const backlog = readBacklog(repoRoot);
  const workItems = (backlog.workItems || [])
    .map((item) => ({
      ...item,
      latestRun: ["debt", "task"].includes(item.kind) ? readLatestWorkflowRun(repoRoot, item.workItemId) : null,
    }))
    .sort((a, b) => String(a.workItemId || "").localeCompare(String(b.workItemId || "")));

  const gitState = parseGitState(repoRoot);

  const pendingTasks = [];
  for (const item of workItems) {
    if (item.status === "done") continue;

    const priorityRank = normalizePriority(item.priority || "P99");
    if (item.status === "todo") {
      pendingTasks.push({
        id: `${item.workItemId}-start`,
        title: `启动 ${item.workItemId}`,
        type: "workflow",
        priority: item.priority || "P99",
        priorityRank,
        relatedWorkItem: item.workItemId,
        relatedPlan: item.planId,
        command: `scripts/workflow/start.sh ${item.workItemId}`,
        action: "workflow.start",
        params: { workItemId: item.workItemId },
        reason: "状态为 todo，需要先启动工作流。",
      });
    }

    pendingTasks.push({
      id: `${item.workItemId}-progress`,
      title: `推进 ${item.workItemId}`,
      type: "workflow",
      priority: item.priority || "P99",
      priorityRank,
      relatedWorkItem: item.workItemId,
      relatedPlan: item.planId,
      command: `scripts/workflow/progress.sh ${item.workItemId}`,
      action: "workflow.progress",
      params: { workItemId: item.workItemId },
      reason: "执行验收命令并更新推进证据。",
    });

    pendingTasks.push({
      id: `${item.workItemId}-close`,
      title: `尝试闭环 ${item.workItemId}`,
      type: "workflow",
      priority: item.priority || "P99",
      priorityRank,
      relatedWorkItem: item.workItemId,
      relatedPlan: item.planId,
      command: `scripts/workflow/close.sh ${item.workItemId}`,
      action: "workflow.close",
      params: { workItemId: item.workItemId },
      reason: "闭环会校验必需文档、依赖与 ADR 约束。",
    });
  }

  const repoTasks = [];
  if (gitState.isDirty) {
    repoTasks.push({
      id: "repo-verify",
      title: "执行门禁聚合校验",
      type: "repo",
      priority: "P1",
      priorityRank: 1,
      relatedWorkItem: "-",
      relatedPlan: "-",
      command: "scripts/ci/verify.sh",
      action: "ci.verify",
      params: {},
      reason: "工作区存在改动，提交前应执行统一门禁。",
    });
  }

  pendingTasks.sort((a, b) => {
    if (a.priorityRank !== b.priorityRank) return a.priorityRank - b.priorityRank;
    return String(a.relatedWorkItem || "").localeCompare(String(b.relatedWorkItem || ""));
  });

  const statusCount = {
    todo: workItems.filter((item) => item.status === "todo").length,
    in_progress: workItems.filter((item) => item.status === "in_progress").length,
    blocked: workItems.filter((item) => item.status === "blocked").length,
    done: workItems.filter((item) => item.status === "done").length,
  };

  const byPlan = new Map();
  for (const item of workItems) {
    const planId = String(item.planId || "unknown");
    if (!byPlan.has(planId)) {
      byPlan.set(planId, {
        planId,
        total: 0,
        todo: 0,
        in_progress: 0,
        blocked: 0,
        done: 0,
      });
    }
    const row = byPlan.get(planId);
    row.total += 1;
    if (row[item.status] !== undefined) row[item.status] += 1;
  }

  const plans = [...byPlan.values()]
    .map((plan) => ({
      ...plan,
      completion: plan.total > 0 ? Number(((plan.done / plan.total) * 100).toFixed(1)) : 0,
    }))
    .sort((a, b) => a.planId.localeCompare(b.planId));

  const experienceDocs = listExperienceDocs(repoRoot);
  const docModuleStatuses = readDocModuleStatuses(repoRoot);
  const primaryPlanRel = resolvePrimaryPlanRel(repoRoot, plans[0]?.planId || "");
  const docsStructure = buildDocsStructure(repoRoot, {
    planRel: primaryPlanRel,
    workflowGuideRel: "docs/02-架构/执行计划/工作流自动推进闭环.md",
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

  return {
    generatedAt: isoNow(),
    sources: {
      backlogFile: BACKLOG_REL,
      planDirectory: backlog.sources?.planDirectory || "docs/02-架构/执行计划/active",
      techDebtFile: backlog.sources?.techDebtFile || "docs/02-架构/技术债清单.md",
      adrIndexFile: backlog.sources?.adrIndexFile || "docs/09-ADR-架构决策/ADR-索引.md",
    },
    model: backlog.model || {
      entity: "work_item",
      idPattern: "WI-PLANYYYYMMDDNN-NN",
    },
    repo: {
      root: repoRoot,
      ...gitState,
    },
    summary: {
      workItemCount: workItems.length,
      planCount: plans.length,
      todoCount: statusCount.todo,
      inProgressCount: statusCount.in_progress,
      blockedCount: statusCount.blocked,
      doneCount: statusCount.done,
      todoTaskCount: pendingTasks.length + repoTasks.length,
      pendingTaskCount: pendingTasks.length,
      repoTaskCount: repoTasks.length,
      docRuleCount: docRuleCatalog.all.length,
      dirtyFileCount: gitState.changedCount,
    },
    plans,
    docsLibrary: { modules: docModules },
    experienceLibrary: {
      checkAction: "docs.library.experience",
      checkTitle: "经验库规则校验",
      lastRun: docModuleStatuses.experience || null,
      docs: experienceDocs,
    },
    docRules: docRuleCatalog,
    docsStructure,
    focusWorkItems: workItems.filter((item) => item.status !== "done"),
    workItems,
    pendingTasks,
    repoTasks,
  };
}

function executeAction(repoRoot, payload) {
  const action = trim(payload.action);
  const workItemId = trim(payload.workItemId);

  let command = null;
  if (["workflow.start", "workflow.progress", "workflow.close", "workflow.full"].includes(action)) {
    if (!WORK_ITEM_ID_RE.test(workItemId)) {
      throw new Error("workItemId 非法，必须为 WI-PLANYYYYMMDDNN-NN");
    }
    command = ["scripts/workflow/run.sh", workItemId, action.split(".", 2)[1]];
  } else if (action === "ci.verify") {
    command = ["scripts/ci/verify.sh"];
  } else if (action === "ci.workflow_sync") {
    command = ["scripts/ci/workflow-sync-check.sh"];
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
    if (!token.startsWith("--")) continue;
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

  if (command === "json") return commandJson(repoRoot, rest);
  if (command === "serve") return commandServe(repoRoot, rest);
  usage();
  return 1;
}

export { buildStatus, resolveRepoRoot };

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = main();
}

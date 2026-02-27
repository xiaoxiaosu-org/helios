# HELIOS — AGENTS.md（入口导航 / 渐进式披露）

本文件是本仓库对人类与智能体的“小而稳定切入点”：先告诉你如何开始、去哪里找真相、以及哪些不变量会被 CI 强制。

更完整的工程治理细则请阅读：`docs/02-架构/工程治理/工程治理与门禁.md`

---

## 0. 从这里开始（推荐阅读顺序）

1) 文档导航（按任务分流）：`docs/README.md`
2) 术语与命名基线：`docs/00-术语表/术语表.md`
3) 系统约束与边界：`docs/02-架构/系统总览.md`
4) 领域对象与不变量：`docs/03-领域模型/核心领域模型.md`
5) 工程智能化路线图（计划入口）：`docs/02-架构/执行计划/README.md`

---

## 1. 本地验证（黄金路径）

优先用脚本而不是“凭感觉”：
- 运行项目门禁脚本：`scripts/ci/verify.sh`
- CI 门禁单一事实来源：
  - `./.github/workflows/quality-gates.yml`
  - `./.github/workflows/doc-check.yml`

---

## 2. 你改了什么，就去哪里补档（任务分流）

- 改 API（HTTP/gRPC/SDK）：更新 `docs/04-接口/`；OpenAPI 产物仅放 `docs/04-接口/OpenAPI/`
- 改事件（类型/字段/语义）：更新 `docs/05-事件/`；Schema 产物仅放 `docs/05-事件/Schemas/`
- 改数据（表/字段/索引/迁移）：更新 `docs/06-数据/`；必须写迁移步骤、校验方式、回滚/补偿
- 改领域（对象/状态机/约束）：更新 `docs/03-领域模型/`；若影响运行态联动 `docs/07-运行态/`
- 改运行态（Trace/窗口/缓存/回放）：更新 `docs/07-运行态/`；必要时写 ADR
- 改安全（鉴权/审计/降级/边界）：更新 `docs/08-安全/`；安全策略变化必须写 ADR
- 改架构边界/依赖方向/引入新基础设施：更新 `docs/02-架构/` 并新增 ADR

---

## 3. 硬不变量（会被 CI 强制）

- `docs/00-09` 顶层目录结构固定，不得随意增删/改名
- 业务代码/配置/SQL 变更必须同步更新 `docs/`（CI 会阻断“只改代码不改文档”）
- 新增 ADR：必须放在 `docs/09-ADR-架构决策/` 且同时更新 `docs/09-ADR-架构决策/ADR-索引.md`
- 关键变更默认必须新增 ADR；仅 hotfix 分支上下文允许先新增 `HOTFIX-*` 作为临时记录（细则见工程治理文件与 CI 提示）
- 关键可追溯字段禁止被直接删除：`traceId`；涉及流程时还包括 `workflowInstanceId`、`stepId`
- 生产代码路径禁止标准输出调试语句：`console.log` / `print(` / `System.out.println(`
- 禁止硬编码密钥（Token/密码/私钥/AccessKey 等）；合并前会做 secrets 扫描
- 必须存在 `CODEOWNERS` 以承载 Owner 审批机制
- 规则文件必须使用 Markdown（`.md`）并使用中文描述（至少关键段落为中文）

---

## 4. 索引机制（避免信息淹没）

- `docs/README.md` 是 docs 总导航入口
- `docs/00-09/*/README.md` 是各域索引页（先读索引，再按链接深入）
- 子目录文档一旦变多（例如同目录 Markdown > 7），应拆分并补该子目录索引页

---

## 5. 子目录 AGENTS.md 规则

子目录允许新增 `AGENTS.md` 作为补充，但只能更严格，不能与根规则冲突；执行顺序为：根 → 父目录链 → 当前目录（近处更严格者优先）。

---

## 6. 提交与合并模板约束（协作默认）

- 默认启用本地 hooks 与提交模板：`scripts/dev/install-git-hooks.sh`
- 每次提交信息必须符合：`type(scope): summary`（支持 `!` 破坏性标记），类型：`feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert`
- 每次提交正文必须包含：`功能:`、`功能与文件映射:`、`涉及文件:`、`主要改动:`、`为什么改:`、`验证:`（模板：`.github/commit_message_template.md`）
- 合并 `main` 必须通过 PR，且 PR 描述必须按 `.github/pull_request_template.md` 填写（至少包含全部模板段落与 1 个 Type 勾选）
- `git commit` 与 `git push`/PR 阶段必须输出结构化改动明细（标题、功能、功能与文件映射、改动原因、文件清单等）
- 执行 `git commit`、`git push`、PR 相关操作时，必须在协作会话中同步打印结构化明细（用户可见），不得仅依赖 hook/CI 日志
- Hook/Workflow/模板/治理文档必须保持一致，并通过：`scripts/docs/git-governance-sync-check.sh`
- 执行远端 `git push` 前，必须先输出“本次改动摘要”（提交列表 + 文件列表）并获得协作者确认
- 项目新增注释、说明、治理文档默认使用中文；确需英文术语时可保留英文术语原文

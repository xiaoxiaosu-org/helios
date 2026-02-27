# HELIOS 文档导航（渐进式披露）

本仓库采用 Docs-as-Code：架构、领域、契约、数据、运行态、安全与关键决策均以 `docs/` 为系统记录（system of record）。

目标：让人类与智能体从一个小而稳定的入口开始，再按任务逐步深入，而不是一次性阅读所有规则。

## 快速分流（你在做什么？）

- 想理解项目整体：先读 `docs/00-术语表/README.md` → `docs/01-产品/README.md` → `docs/02-架构/README.md` → `docs/03-领域模型/README.md`
- 想了解工程智能化演进：读 `docs/02-架构/执行计划/README.md` → `docs/02-架构/质量评分与演进.md` → `docs/02-架构/技术债清单.md`
- 想新增/修改 API：读 `docs/04-接口/README.md`（并确保 OpenAPI 产物落在 `docs/04-接口/OpenAPI/`）
- 想新增/修改事件：读 `docs/05-事件/README.md`（并确保 Schema 产物落在 `docs/05-事件/Schemas/`）
- 想新增/修改数据结构：读 `docs/06-数据/README.md`（迁移步骤、校验方式、回滚/补偿必写）
- 想做可观测/回放/复盘：读 `docs/07-运行态/README.md`（Trace 与回放资产入口）
- 想做安全相关变更：读 `docs/08-安全/README.md`（安全策略变化必须写 ADR）
- 想理解“为什么这么做”：读 `docs/09-ADR-架构决策/README.md` → `docs/09-ADR-架构决策/ADR-索引.md`

## 固定顶层（00-09 不变）

`docs/00-09` 顶层目录结构固定，不得随意增删/改名；允许在顶层目录内按业务域/服务名扩展子目录。

各顶层索引页：
- `docs/00-术语表/README.md`
- `docs/01-产品/README.md`
- `docs/02-架构/README.md`
- `docs/03-领域模型/README.md`
- `docs/04-接口/README.md`
- `docs/05-事件/README.md`
- `docs/06-数据/README.md`
- `docs/07-运行态/README.md`
- `docs/08-安全/README.md`
- `docs/09-ADR-架构决策/README.md`

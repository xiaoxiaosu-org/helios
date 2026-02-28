# 执行计划（索引）

本目录用于把“工程智能化能力”做成可追踪、可审计、可长期演进的计划资产。

约定：
- `active/`：正在推进的计划与里程碑
- `completed/`：已完成计划（归档）

## 当前计划（active）
- 工程智能化路线图：`docs/02-架构/执行计划/active/PLAN-20260227-工程智能化路线图.md`
- PR 校验机制增强计划（防遗忘版）：`docs/02-架构/执行计划/active/PLAN-20260228-PR校验机制增强计划.md`

## 自动编排入口
- 工作流映射（单一事实源）：`docs/02-架构/执行计划/workflow-map.yaml`
- 统一工作项主文件（WorkItem）：`docs/02-架构/执行计划/backlog.yaml`
- 自动推进与闭环手册：`docs/02-架构/执行计划/工作流自动推进闭环.md`
- 统一总览 JSON（待执行任务/系统现状）：`scripts/workflow/run.sh overview json`
- 本地管理看板（Node）：`scripts/workflow/run.sh overview serve 127.0.0.1 8787`
- backlog 同步：`scripts/workflow/run.sh backlog build`
- 文档库校验与统一（全量/模块）：`scripts/docs/library-check.sh all` / `scripts/docs/library-check.sh experience`

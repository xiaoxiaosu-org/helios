# 执行计划（索引）

本目录用于把“工程智能化能力”沉淀为可追踪、可审计、可迁移的计划资产。

约定：
- `active/`：正在推进且可执行的唯一专题计划
- `completed/`：已完成或归档计划（只读历史）

## 当前计划（active）
- P0在制项收敛与退场治理计划：`docs/02-架构/执行计划/active/PLAN-20260228-02-P0在制项收敛与退场治理计划.md`
- 工程智能化路线图（唯一执行计划）：`docs/02-架构/执行计划/active/PLAN-20260227-01-工程智能化路线图.md`
- 统一计划模板（WorkItem 最小单元）：`docs/02-架构/执行计划/PLAN-模板-WorkItem.md`
- WorkItem 编号与治理约束：`docs/02-架构/执行计划/WorkItem-最小单元与编号策略.md`

## 已完成/归档（completed）
- PR 校验机制增强计划（历史归档）：`docs/02-架构/执行计划/completed/PLAN-20260228-01-PR校验机制增强计划.md`

## 自动编排入口
- 统一工作项主文件（唯一执行源）：`docs/02-架构/执行计划/backlog.yaml`
- 自动推进与闭环手册：`docs/02-架构/执行计划/工作流自动推进闭环.md`
- WorkItem 列表：`scripts/workflow/run.sh list all`
- 计划初始化（自动分配日内序号）：`scripts/workflow/run.sh plan-add --title "专题标题" --owner "repo-owner"`
- WorkItem 新增：`scripts/workflow/run.sh add --plan-id PLAN-YYYYMMDD-NN --kind debt --title ... --owner ... --priority P1`
- 统一总览 JSON（待执行任务/系统现状）：`scripts/workflow/run.sh overview json`
- 本地管理看板（Node）：`scripts/workflow/run.sh overview serve 127.0.0.1 8787`
- backlog 规范化：`scripts/workflow/run.sh backlog build`
- backlog 稳定性校验：`scripts/workflow/run.sh backlog check`
- 计划模板一致性校验：`scripts/ci/plan-template-check.sh`
- 文档库校验与统一（全量/模块）：`scripts/docs/library-check.sh all` / `scripts/docs/library-check.sh experience`

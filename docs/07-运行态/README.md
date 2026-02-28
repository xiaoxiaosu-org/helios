# 07-运行态（索引）

## 本目录解决什么问题
- Trace 传播、上下文模型、窗口/缓存、回放与复盘机制如何执行与验证？

## 先读什么
- 运行态总览：`docs/07-运行态/运行态总览.md`
- 产物与证据目录规范：`docs/07-运行态/产物与证据目录规范.md`
- 任务沙盒最小实现（CAP-001）：`docs/07-运行态/任务沙盒最小实现.md`
- 可观测查询剧本（CAP-003）：`docs/07-运行态/可观测查询剧本.md`
- 仓库总览看板（Node 统一入口）：`scripts/workflow/run.sh overview serve 127.0.0.1 8787`
- 统一工作项主文件（WorkItem）：`docs/02-架构/执行计划/backlog.yaml`
- 文档库校验与统一：`scripts/docs/library-check.sh all`

## 最低不变量
- 关键链路必须携带并记录 `traceId`
- 涉及流程时需关联 `workflowInstanceId`、`stepId`

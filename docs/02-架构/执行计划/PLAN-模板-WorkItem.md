# PLAN-YYYYMMDD-NN：<计划标题>

> 适用范围：本模板用于 active 执行计划，统一以 WorkItem 为最小单元。

## 背景与目标

- 背景：
- 问题：
- 目标：
- 非目标：

## WorkItem 清单

状态枚举：`todo` / `in_progress` / `blocked` / `done`

| WorkItem | 类型 | 标题 | Owner | 状态 | 验收命令 | 证据目录 |
|---|---|---|---|---|---|---|
| WI-PLAN2026022701-01 | capability | 示例条目 | repo-owner | in_progress | `scripts/workflow/run.sh WI-PLAN2026022701-01 progress` | `artifacts/workflow/` |

## 推进记录

| 日期 | WorkItem | 动作 | 结果 | 备注 |
|---|---|---|---|---|
| 2026-02-28 | WI-PLAN2026022701-01 | `start` | pass | - |

## 验收与证据

- 统一验收入口：`scripts/workflow/run.sh <WI-PLANYYYYMMDDNN-NN> [start|progress|close|full]`
- 统一证据目录：`artifacts/workflow/<WI-ID>/<run-id>/`
- 事件追踪文件：`artifacts/workflow/events/<WI-ID>.jsonl`

## 风险与阻塞

- 风险：
- 阻塞：
- 解除阻塞动作：

## 下一步

1. 下一步动作 1
2. 下一步动作 2

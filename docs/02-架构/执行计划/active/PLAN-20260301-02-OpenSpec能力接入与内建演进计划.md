# PLAN-20260301-02：OpenSpec能力接入与内建演进计划

## 背景与目标

- 背景：项目已形成较完整的工程治理闭环（WorkItem + CI 门禁 + docs/ADR 体系），但缺少规范驱动的变更编排能力（proposal/spec/design/tasks/apply/archive）。
- 问题：若直接全量内建，投入大且见效慢；若仅依赖外部 OpenSpec，长期存在可控性与演进自主性不足。
- 目标：采用“短期兼容接入、长期内建替代”的双阶段路径，将 OpenSpec 能力纳入现有系统并逐步内化为项目内能力。
- 非目标：不改变 WorkItem 作为唯一执行主键；不绕过现有门禁直接使用外部流程；不在首期重做全部治理体系。

## WorkItem 清单

状态枚举：`todo` / `in_progress` / `blocked` / `done`

| WorkItem | 类型 | 标题 | Owner | 状态 | 验收命令 | 证据目录 |
|---|---|---|---|---|---|---|
| WI-PLAN2026030102-01 | initiative | 制定OpenSpec接入基线与阶段目标 | repo-owner | in_progress | `scripts/workflow/run.sh WI-PLAN2026030102-01 progress` | `artifacts/workflow/` |
| WI-PLAN2026030102-02 | task | 短期兼容接入OpenSpec并建立变更工件目录规范 | repo-owner | todo | `scripts/workflow/run.sh WI-PLAN2026030102-02 progress` | `artifacts/workflow/` |
| WI-PLAN2026030102-03 | task | 建立OpenSpec到WorkItem和docs/ADR的自动映射 | repo-owner | todo | `scripts/workflow/run.sh WI-PLAN2026030102-03 progress` | `artifacts/workflow/` |
| WI-PLAN2026030102-04 | task | 将OpenSpec校验接入CI并与现有门禁串联 | repo-owner | todo | `scripts/workflow/run.sh WI-PLAN2026030102-04 progress` | `artifacts/workflow/` |
| WI-PLAN2026030102-05 | task | 沉淀内建Spec内核设计与数据模型（artifact graph/delta/validate/apply） | repo-owner | todo | `scripts/workflow/run.sh WI-PLAN2026030102-05 progress` | `artifacts/workflow/` |
| WI-PLAN2026030102-06 | task | 分阶段替换外部OpenSpec能力并保持结果一致性 | repo-owner | todo | `scripts/workflow/run.sh WI-PLAN2026030102-06 progress` | `artifacts/workflow/` |
| WI-PLAN2026030102-07 | task | 完成外部依赖退出评审与长期演进机制 | repo-owner | todo | `scripts/workflow/run.sh WI-PLAN2026030102-07 progress` | `artifacts/workflow/` |

## 推进记录

| 日期 | WorkItem | 动作 | 结果 | 备注 |
|---|---|---|---|---|
| 2026-03-01 | WI-PLAN2026030102-01 | 初始化计划 | pass | 自动创建首个 WorkItem |
| 2026-03-01 | WI-PLAN2026030102-02 ~ WI-PLAN2026030102-07 | 计划拆解入库 | pass | OpenSpec 接入与内建演进任务已入 backlog 主链路 |

## 验收与证据

- 统一验收入口：`scripts/workflow/run.sh <WI-PLANYYYYMMDDNN-NN> [start|progress|close|full]`
- 统一证据目录：`artifacts/workflow/<WI-ID>/<run-id>/`
- 事件追踪文件：`artifacts/workflow/events/<WI-ID>.jsonl`
- 阶段验收口径：
  1) 短期：OpenSpec 产物可进入本仓库并通过现有 docs/CI/ADR 门禁；
  2) 中期：OpenSpec 与 WorkItem 状态、验收、证据目录实现自动对齐；
  3) 长期：项目内建 Spec 内核具备等价能力并可替换外部依赖。

## 风险与阻塞

- 风险：双轨阶段（外部 OpenSpec + 内建能力）可能出现状态漂移与事实源冲突。
- 风险：内建替代期间若缺乏一致性回归，可能导致规范解析与归档语义偏差。
- 阻塞：尚未建立 OpenSpec 产物与 WorkItem 状态的自动同步校验。
- 解除阻塞动作：优先交付映射脚本与 CI 一致性检查，再推进内建替代开发。

## 下一步

1. 启动 `WI-PLAN2026030102-02`，先建立短期兼容接入规范（目录、命名、提交口径）。
2. 启动 `WI-PLAN2026030102-03/04`，完成自动映射与 CI 串联，确保外接能力不绕过现有门禁。
3. 启动 `WI-PLAN2026030102-05`，形成内建 Spec 内核 ADR 与技术设计。
4. 按 `WI-PLAN2026030102-06/07` 分阶段替换并退出外部依赖。

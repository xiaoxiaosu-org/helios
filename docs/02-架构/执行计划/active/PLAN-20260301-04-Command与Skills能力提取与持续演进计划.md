# PLAN-20260301-04：Command与Skills能力提取与持续演进计划

## 背景与目标

- 背景：项目内已经存在可复用能力资产（如 `.github/prompts/`、`.github/skills/`），但缺少统一分类、版本化与演进节奏，导致复用效率与可维护性不稳定。
- 问题：能力沉淀方式不统一，`command` 与 `skills` 的边界、命名、触发词、验收口径与退场机制未形成稳定约束。
- 目标：建立“能力识别 -> 提取实现 -> 门禁接入 -> 度量复盘 -> 持续演进”的闭环，将项目内高频能力系统化沉淀为 `command` 与 `skills`。
- 非目标：不重构现有 WorkItem 主链路；不绕过 `docs/`、CI 与 ADR 既有治理门禁；不在本计划内替代外部工具全部能力。

## 定义基线（系统级 / 项目级）

- `command`：
  1. 系统级：Codex 内置 Slash Commands（官方固定命令集）。
  2. 用户级：`$CODEX_HOME/prompts`（默认 `~/.codex/prompts`）的 custom prompts。
  3. 项目级：本项目当前采用仓库内 `.github/prompts/` 作为项目资产沉淀目录，由工程治理流程托管。
- `skills`：
  1. 系统级：Codex 内置 system skills + `$CODEX_HOME/skills`（默认 `~/.codex/skills`）。
  2. 项目级：本项目当前采用仓库内 `.github/skills/` 作为项目资产沉淀目录，由工程治理流程托管。
- 本计划治理口径：在 Helios 仓库内，以 `.github/prompts/` 与 `.github/skills/` 作为“项目级能力事实源”，并与 `docs/02-架构/执行计划/backlog.yaml` 双向对齐。

## WorkItem 清单

状态枚举：`todo` / `in_progress` / `blocked` / `done`

| WorkItem | 类型 | 标题 | Owner | 状态 | 验收命令 | 证据目录 |
|---|---|---|---|---|---|---|
| WI-PLAN2026030104-01 | initiative | 建立command与skills系统级/项目级定义基线 | repo-owner | in_progress | `scripts/workflow/run.sh WI-PLAN2026030104-01 progress` | `artifacts/workflow/` |
| WI-PLAN2026030104-02 | capability | 盘点项目内候选能力并完成command/skills归类矩阵 | repo-owner | todo | `scripts/workflow/run.sh WI-PLAN2026030104-02 progress` | `artifacts/workflow/` |
| WI-PLAN2026030104-03 | task | 落地第一批command（项目级）并统一模板与触发词 | repo-owner | todo | `scripts/workflow/run.sh WI-PLAN2026030104-03 progress` | `artifacts/workflow/` |
| WI-PLAN2026030104-04 | task | 落地第一批skills（项目级）并补齐脚本/参考资料 | repo-owner | todo | `scripts/workflow/run.sh WI-PLAN2026030104-04 progress` | `artifacts/workflow/` |
| WI-PLAN2026030104-05 | task | 建立command/skills文档映射、索引与示例 | repo-owner | todo | `scripts/workflow/run.sh WI-PLAN2026030104-05 progress` | `artifacts/workflow/` |
| WI-PLAN2026030104-06 | task | 将command/skills纳入CI门禁与一致性检查 | repo-owner | todo | `scripts/workflow/run.sh WI-PLAN2026030104-06 progress` | `artifacts/workflow/` |
| WI-PLAN2026030104-07 | capability | 建立command/skills质量度量与发布节奏（持续演进） | repo-owner | todo | `scripts/workflow/run.sh WI-PLAN2026030104-07 progress` | `artifacts/workflow/` |
| WI-PLAN2026030104-08 | debt | 收敛重复能力与僵尸command/skills并形成退场机制（持续演进） | repo-owner | todo | `scripts/workflow/run.sh WI-PLAN2026030104-08 progress` | `artifacts/workflow/` |

## 推进记录

| 日期 | WorkItem | 动作 | 结果 | 备注 |
|---|---|---|---|---|
| 2026-03-01 | WI-PLAN2026030104-01 | 初始化计划 | pass | 自动创建首个 WorkItem |
| 2026-03-01 | WI-PLAN2026030104-02 ~ WI-PLAN2026030104-08 | 计划拆解入库 | pass | 已纳入 backlog 主链路并完成计划内映射 |

## 验收与证据

- 统一验收入口：`scripts/workflow/run.sh <WI-PLANYYYYMMDDNN-NN> [start|progress|close|full]`
- 统一证据目录：`artifacts/workflow/<WI-ID>/<run-id>/`
- 事件追踪文件：`artifacts/workflow/events/<WI-ID>.jsonl`
- 计划级验收口径：
  1) 能力可追踪：每个新增/改造能力可映射到唯一 WorkItem 与文档入口；
  2) 能力可验证：`scripts/ci/verify.sh` 与相关治理检查可稳定通过；
  3) 能力可复用：首批 `command` 与 `skills` 在真实场景被复用并形成记录；
  4) 能力可演进：每迭代周期完成新增、优化、退场至少各一项评估。

## 持续演进机制

- 发布节奏：
  1. 周节奏：每周一次能力盘点（新增候选/低效能力/僵尸能力）。
  2. 月节奏：每月一次结构化复盘（复用率、失败率、维护成本、文档新鲜度）。
- 版本化规则：
  1. `command` 与 `skills` 变更必须附带版本注记（变更原因、影响范围、回滚方式）。
  2. 破坏性变更需在计划与治理文档中显式标记并给出迁移窗口。
- 度量指标（最小集）：
  1. 覆盖率：高频任务被 `command/skills` 覆盖比例；
  2. 复用率：能力在真实任务中被调用次数；
  3. 成功率：能力触发后一次完成率；
  4. 维护成本：单能力月均修改次数与修复耗时。
- 退场机制：
  1. 连续两个评估周期低复用、且高维护成本的能力进入退场评估；
  2. 退场前必须给出替代路径与迁移说明；
  3. 退场后保留归档记录与回滚窗口。

## 风险与阻塞

- 风险：能力边界定义不稳，导致 `command` 与 `skills` 交叉重复，增加维护成本。
- 风险：只沉淀能力文件、不接入门禁与度量，后续会再次失控。
- 阻塞：候选能力分散在历史对话、脚本与文档中，盘点成本较高。
- 解除阻塞动作：先交付归类矩阵与最小指标，再通过 CI 与周期复盘强制收敛。

## 下一步

1. 推进 `WI-PLAN2026030104-01/02`，输出首版候选能力清单与归类矩阵。
2. 启动 `WI-PLAN2026030104-03/04`，先落地第一批高频 `command` 与 `skills`。
3. 启动 `WI-PLAN2026030104-05/06`，完成文档映射与 CI 门禁串联。
4. 启动 `WI-PLAN2026030104-07/08`，固化“持续演进 + 退场”机制并纳入周期治理。

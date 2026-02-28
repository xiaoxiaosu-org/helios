# PLAN-20260228-07：Harness Engineering能力对齐补齐

## 背景与目标

- 背景：参考 OpenAI《Harness Engineering》实践，当前仓库已具备计划主源、门禁、文档联动与基础自动化能力，但高自治工程闭环仍有缺口。
- 问题：现有能力更偏“治理与校验”，在 agent 协同评审、端到端自治执行、可读性 harness、吞吐治理与后台熵治理方面仍不完整。
- 目标：把差距能力全部纳入可执行 WorkItem，形成对齐路线，并通过门禁与质量评分持续评估演进效果。
- 非目标：不追求一次性重建完整平台，不绕过现有计划/门禁机制直接引入并行流程。

## WorkItem 清单

状态枚举：`todo` / `in_progress` / `blocked` / `done`

| WorkItem | 类型 | 标题 | Owner | 状态 | 验收命令 | 证据目录 |
|---|---|---|---|---|---|---|
| WI-PLAN2026022807-01 | initiative | 计划初始化（待拆解） | repo-owner | todo | `scripts/workflow/run.sh WI-PLAN2026022807-01 progress` | `artifacts/workflow/` |
| WI-PLAN2026022807-02 | task | 建立差距基线与能力成熟度评分（对齐Harness Engineering） | repo-owner | todo | `scripts/workflow/backlog.sh check` + `scripts/ci/plan-template-check.sh` | `artifacts/workflow/` |
| WI-PLAN2026022807-03 | task | 建设Agent-to-Agent评审闭环（本地+云评审器） | repo-owner | todo | `scripts/ci/verify.sh` + `scripts/workflow/backlog.sh check` | `artifacts/workflow/` |
| WI-PLAN2026022807-04 | task | 建设工作树级可启动环境与隔离观测栈 | repo-owner | todo | `scripts/ci/verify.sh` + `scripts/workflow/backlog.sh check` | `artifacts/workflow/` |
| WI-PLAN2026022807-05 | task | 建设UI可读性Harness（CDP快照/前后对比视频） | repo-owner | todo | `scripts/ci/verify.sh` + `scripts/workflow/backlog.sh check` | `artifacts/workflow/` |
| WI-PLAN2026022807-06 | task | 建设自治执行闭环（复现->修复->验证->PR->反馈->合并） | repo-owner | todo | `scripts/ci/verify.sh` + `scripts/docs/git-governance-sync-check.sh` | `artifacts/workflow/` |
| WI-PLAN2026022807-07 | task | 建设吞吐治理能力（最小阻断门禁+自动后续修复） | repo-owner | todo | `scripts/ci/verify.sh` + `scripts/docs/update-quality-score.sh --check --sync-out artifacts/ci/cap-plan-sync` | `artifacts/workflow/` |
| WI-PLAN2026022807-08 | task | 建设后台熵治理机制（垃圾回收/机械重构任务） | repo-owner | todo | `scripts/docs/gardening.sh --out artifacts/ci/doc-gardening` + `scripts/ci/verify.sh` | `artifacts/workflow/` |
| WI-PLAN2026022807-09 | debt | 完成Harness Engineering能力对齐收口与持续评估 | repo-owner | todo | `scripts/ci/verify.sh` + `scripts/workflow/backlog.sh check` + `scripts/ci/plan-template-check.sh` | `artifacts/workflow/` |

## 推进记录

| 日期 | WorkItem | 动作 | 结果 | 备注 |
|---|---|---|---|---|
| 2026-02-28 | WI-PLAN2026022807-01 | 初始化计划 | pass | 自动创建首个 WorkItem |
| 2026-02-28 | WI-PLAN2026022807-02 ~ WI-PLAN2026022807-09 | 补齐可执行拆解 | pass | 覆盖差距评估、自治执行、吞吐治理、熵治理与收口机制 |

## 差距映射（现状 vs 目标）

| 维度 | 现状能力 | 主要差距 | 对应WI |
|---|---|---|---|
| 评审模式 | 已有门禁与模板校验 | 缺少 agent-to-agent 多评审器闭环 | WI-PLAN2026022807-03 |
| 执行环境 | 已有 workflow 编排与证据目录 | 缺少工作树级启动与隔离观测栈的标准化运行面 | WI-PLAN2026022807-04 |
| UI 可读性验证 | 有基础 UI 验证能力 | 缺少 CDP 快照与 before/after 视频回放基线 | WI-PLAN2026022807-05 |
| 自治开发闭环 | 有计划/门禁/PR 治理基础 | 缺少端到端自治链路（复现到合并） | WI-PLAN2026022807-06 |
| 吞吐治理 | 有较强硬门禁 | 缺少“最小阻断 + 自动后续修复”的平衡机制 | WI-PLAN2026022807-07 |
| 熵控制 | 有 doc-gardening | 缺少后台常驻的机械重构/垃圾回收机制 | WI-PLAN2026022807-08 |
| 统一评估 | 有质量评分基础 | 缺少针对上述能力的统一成熟度基线与闭环评估 | WI-PLAN2026022807-02 / WI-PLAN2026022807-09 |

## 验收与证据

- 统一验收入口：`scripts/workflow/run.sh <WI-PLANYYYYMMDDNN-NN> [start|progress|close|full]`
- 统一证据目录：`artifacts/workflow/<WI-ID>/<run-id>/`
- 事件追踪文件：`artifacts/workflow/events/<WI-ID>.jsonl`

## 风险与阻塞

- 风险：若先做实现不先定义成熟度基线，后续“是否达标”会缺乏统一判断标准。
- 风险：自治能力引入后若缺少吞吐策略，可能导致门禁成本上升影响交付节奏。
- 阻塞：当前无硬阻塞，主要是跨机制改造的先后顺序管理。
- 解除阻塞动作：先完成差距基线（WI-07-02），再并行推进执行/评审/观测能力，最后统一收口。

## 下一步

1. 启动 `WI-PLAN2026022807-02`，先完成差距基线与成熟度评分框架。
2. 并行启动 `WI-PLAN2026022807-03` 与 `WI-PLAN2026022807-04`，补齐评审与运行面能力底座。
3. 启动 `WI-PLAN2026022807-05` 与 `WI-PLAN2026022807-06`，形成可读性 harness 与自治执行闭环。
4. 启动 `WI-PLAN2026022807-07` 与 `WI-PLAN2026022807-08`，平衡吞吐与持续熵治理。
5. 启动 `WI-PLAN2026022807-09`，统一收口并纳入持续评估。

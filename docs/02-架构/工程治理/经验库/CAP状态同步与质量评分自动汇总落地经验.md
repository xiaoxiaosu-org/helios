# CAP 状态同步与质量评分自动汇总落地经验

## 背景

在工程智能化路线图长期推进中，曾出现“计划状态显示 Planned，但 CAP 验收已经通过”的漂移问题。
这会导致闭环判断失真，出现“看起来在推进，实际上已完成但未回写文档”的治理盲区。

## 目标

建立两条硬约束：
1. 路线图状态与 CAP 验收结果必须一致。
2. 质量评分文档由脚本自动汇总，避免手工维护滞后。

## 落地做法

1. 新增一致性门禁：`scripts/ci/cap-plan-sync-check.sh`
- 规则：
  - 路线图为 `Done`，验收返回码必须是 `0`。
  - 验收返回码为 `0`，路线图必须是 `Done`。
- 产物：`artifacts/ci/cap-plan-sync/cap-status.tsv` 与汇总报告。

2. 新增质量评分自动汇总脚本：`scripts/docs/update-quality-score.sh`
- 自动区块通过标记维护：`AUTO-QUALITY-SCORE:BEGIN/END`
- 支持 `--check` 模式，在 CI 中阻断“脚本结果与文档不一致”。

3. 接入门禁链路
- 本地聚合：`scripts/ci/verify.sh`
- CI：`quality-gates.yml`

## 效果

- 文档状态与验收结果形成双向约束，减少状态漂移。
- 质量评分从“手工快照”升级为“脚本生成 + CI 校验”。
- CAP 完成信号与工作流闭环判断可组合使用，减少误判。

## 注意事项

- 若 CAP 验收脚本本身递归调用 `verify.sh`，需避免在一致性检查中形成递归链路。
- 自动汇总区块建议使用提交时间作为稳定时间戳，避免每次 CI 都触发无意义差异。
- 新增 CAP 时，应同步：路线图表格、`scripts/cap/CAP-XXX/verify.sh`、状态同步检查。

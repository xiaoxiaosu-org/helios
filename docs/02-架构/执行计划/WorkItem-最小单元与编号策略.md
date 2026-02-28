# WorkItem 最小单元与编号策略

## 目标

解决计划推进中“多编号体系并行、跨计划重复维护”问题，形成可机器校验的唯一模型。

## 统一最小单元

所有计划项统一抽象为 `WorkItem`，最小字段：
- `workItemId`: `WI-PLANYYYYMMDDNN-NN`（全局主键）
- `planId`: `PLAN-YYYYMMDD-NN`（唯一归属计划）
- `kind`: `initiative|capability|task|debt`
- `status`: `todo|in_progress|blocked|done`
- `links.dependsOnWorkItems`: 依赖项
- `workflow`: 触发路径、必需文档、验收命令、闭环检查

## 编号约定

- 专题唯一计划：一个专题只允许一个 active plan。
- 计划内编号：`NN` 从 `01` 开始递增，只在该计划内维护。
- 前缀绑定：`workItemId` 必须匹配 `planId` 前缀。
  - 例如：`planId=PLAN-20260227-01` 对应 `WI-PLAN2026022701-01`。

## 强约束

- 同一 `workItemId` 只能在一个 active plan 中出现。
- backlog 中每个 WorkItem 必须且只能归属一个 `planId`。
- 不再兼容旧执行输入（`TD-*`、`CAP-*`、`workflow-map.yaml`）。

## 门禁落地

- `scripts/ci/plan-template-check.sh`
  - 校验模板段落完整性。
  - 校验 `WI-PLAN*-**` 编号与 `planId` 绑定关系。
  - 校验 WorkItem 不跨计划重复定义。
  - 校验 active 计划与 `backlog.yaml` 双向一致。
- `scripts/workflow/backlog.sh check`
  - 校验 backlog 结构、编号、依赖和规范化输出。

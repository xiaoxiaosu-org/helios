# ADR-20260228: TD/CAP 工作流编排器与闭环门禁

## 状态
Accepted

## 日期
2026-02-28

## 背景
- 仓库已有技术债清单、执行计划、门禁与经验库，但它们之间主要靠人工串联。
- 会话启动后缺少统一“下一步动作”来源，容易出现流程漏项（只改代码、不补文档、未跑验收）。
- 需要把“追踪-验证-推进-闭环”编排成可执行状态机。

## 决策
- 新增 `docs/02-架构/执行计划/workflow-map.yaml` 作为编排单一事实源。
- 新增工作流脚本：
  - `scripts/workflow/start.sh`
  - `scripts/workflow/progress.sh`
  - `scripts/workflow/close.sh`
  - `scripts/workflow/run.sh`
- 新增 CI 联动检查脚本 `scripts/ci/workflow-sync-check.sh`，当触发路径变更时强制要求同步文档。
- 在 `quality-gates.yml` 与 `scripts/ci/verify.sh` 接入 workflow-sync 检查。
- 新增定时工作流 `.github/workflows/tech-debt-sweep.yml` 执行技术债巡检。

## 影响

### 正面影响
- 工作流启动后可自动得到分支、状态更新、验收命令与闭环步骤，减少人工协调成本。
- 文档联动从“建议”升级为“门禁”，可持续避免“只改代码不改文档”。
- 定时巡检可提前暴露超期技术债，减少堆积。

### 负面影响
- 需要维护 `workflow-map.yaml`，新增 TD/CAP 时要同步更新映射。
- 门禁更严格，短期可能增加因流程漏项导致的 CI 失败。

## 备选方案
- 继续人工串联：拒绝，无法稳定保证闭环与可审计性。
- 仅靠会话提示词：拒绝，提示不可机械验证且不可持续审计。

## 版本影响
- 是否影响 API：否
- 是否影响事件模型：否
- 是否影响数据结构：否

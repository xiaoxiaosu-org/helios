# ADR-20260228: CAP-010 PR 校验鲁棒性增强

## 状态
Accepted

## 日期
2026-02-28

## 背景
- 出现过“PR 检查通过但规则实际漏检”的情况，说明仅靠门禁脚本执行成功不足以保证规则有效。
- 在 rebase + force-push 后，`push` 事件存在 `before SHA` 不可达导致 workflow 误失败的风险。

## 决策
- 新增 `scripts/ci/gate-selftest.sh`，对关键门禁（CAP-004/CAP-007）执行正反例回归。
- 将 `gate-selftest` 接入 `scripts/ci/verify.sh` 与 `quality-gates.yml`，作为强制门禁。
- 在 `doc-check.yml` 与 `quality-gates.yml` 的 push 差异计算增加 `before SHA` 不可达回退（merge-base + 单提交兜底）。
- 同步更新执行计划、治理对照清单与经验库，形成系统记录闭环。

## 影响

### 正面影响
- 降低“脚本可执行但规则失效”的漏检风险。
- 降低 rebase/force-push 场景下的 CI 假失败概率。
- 规则变更的验证方式可复用、可审计。

### 负面影响
- workflow 与门禁脚本复杂度上升，维护成本增加。
- 自测用例需要随规则演进同步维护。

## 备选方案
- 仅加强人工评审，不增加自动化自测：拒绝，无法稳定覆盖回归。
- 保持现有 diff 计算逻辑：拒绝，已在 push 场景出现真实失败。

## 版本影响
- 是否影响 API：否
- 是否影响事件模型：否
- 是否影响数据结构：否

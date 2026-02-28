# PR 校验鲁棒性与门禁自测落地经验

> 版本：v1.0
> 最近更新：2026-02-28
> 对应实现：`scripts/ci/gate-selftest.sh`、`scripts/ci/verify.sh`、`.github/workflows/quality-gates.yml`、`.github/workflows/doc-check.yml`

## 1. 背景

2026-02-27 晚上的两个 PR 虽然 CI 通过，但次日复盘发现门禁存在漏检：
- 架构依赖门禁脚本出现“可执行但失效”的情况，CI 仍为绿。
- 技术债清单校验口径早期偏宽，出现“部分非法仍可过”。

结论：仅验证“脚本执行成功”不足以证明“规则有效”。

## 2. 本次落地

1. 增加门禁自测脚本 `scripts/ci/gate-selftest.sh`：
- 覆盖 `arch-check` 的正反例（非法依赖应失败、合法依赖应通过）。
- 覆盖技术债清单验收脚本正反例（缺关键字段/非法状态应失败）。

2. 接入统一入口：
- `scripts/ci/verify.sh` 增加 `gate-selftest`，本地与 pre-push 同步执行。
- `quality-gates.yml` 增加 `Run gate self-tests` 步骤，CI 强制执行。

3. 修复 push 事件回归风险：
- 在 `doc-check.yml` 与 `quality-gates.yml` 的 diff 计算加入 `before SHA` 不可达回退。
- 回退策略：优先 merge-base，兜底单提交 `diff-tree`，避免 `fatal: bad object`。

## 3. 踩坑与修复

### 3.1 force-push 后 push 事件 before SHA 不可达

- 现象：workflow 在 `push` 场景 `git diff BEFORE AFTER` 直接失败，报 `fatal: bad object`。
- 原因：rebase + force-push 后，旧 before 提交在远端不可达。
- 修复：增加可达性判断，失败后回退到 `merge-base(default_branch, after_sha)`。

### 3.2 门禁脚本“空跑通过”不可见

- 现象：规则写错时，脚本仍返回 0，CI 无法发现。
- 修复：把典型反例固化为自测脚本，要求 CI 必须执行。

## 4. 复用建议

1. 所有新增门禁脚本默认配套 `gate-selftest` 用例，不再接受“先上线后补测”。
2. workflow 中凡使用 `github.event.before` 的步骤，都必须有不可达回退。
3. 规则变更 PR 默认附“反例验证结果”，作为评审硬要求。

## 5. 验证命令

```bash
scripts/ci/gate-selftest.sh
scripts/ci/verify.sh
scripts/docs/git-governance-sync-check.sh
```

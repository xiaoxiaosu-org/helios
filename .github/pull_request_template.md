## 变更摘要（Summary）

<!-- 用 1-3 句说明：为什么改、改了什么、影响范围 -->

## 变更类型（Type）

- [ ] Feature
- [ ] Bugfix
- [ ] Refactor
- [ ] Docs
- [ ] Chore

## 验证（Verification）

- [ ] 本地通过：`scripts/ci/verify.sh`
- [ ] 如涉及 CAP：已通过 `scripts/cap/verify.sh CAP-00X` 并产出 `artifacts/`

## docs / ADR（系统记录）

- [ ] 已按“你改了什么，就去哪里补档”更新 `docs/`（或说明不需要）
- [ ] 若为关键变更：已新增或更新 ADR（`docs/09-ADR-架构决策/`），并更新索引

## 可观测性 / Trace

- [ ] 关键链路可通过 `traceId` 定位（如适用）

## 安全（Security）

- [ ] 未引入硬编码密钥（Token/密码/私钥等）
- [ ] 如涉及鉴权/审计/边界：已更新 `docs/08-安全/`（或说明不需要）

## 影响与回滚（Impact / Rollback）

- [ ] 说明潜在影响与回滚/补偿策略（如适用）


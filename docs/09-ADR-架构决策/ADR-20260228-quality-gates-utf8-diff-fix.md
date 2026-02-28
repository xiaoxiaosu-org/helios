# ADR-20260228: quality-gates 中文路径 diff 口径修复

## 状态
Accepted

## 日期
2026-02-28

## 背景
- workflow-sync 门禁依赖 `changed_files.txt` 与 `workflow-map` 的文档路径匹配。
- `quality-gates.yml` 在计算 changed files 时未显式设置 `core.quotepath=false`，中文路径会被转义为八进制，导致匹配失败。
- 结果表现为：PR 实际已更新 required docs，但 CI 仍误判“未同步文档”。

## 决策
- 在 `quality-gates.yml` 的 `Compute changed files` 步骤中统一设置 `git config core.quotepath false`。
- 同步更新 `docs/02-架构/工程治理/Git门禁与模板对照清单.md`，将 workflow-sync 与 tech-debt-sweep 纳入实现/文档/自动约束对照。
- 更新 `workflow-map.yaml`（TD-001 的 required_docs）以覆盖治理清单更新场景。

## 影响

### 正面影响
- 修复中文路径环境下的 workflow-sync 假阳性失败，恢复 CI 稳定性。
- Git 门禁文档与实现保持一致，满足“实现变更必须同步对照清单”的治理要求。

### 负面影响
- 增加一次 ADR 维护成本。

## 备选方案
- 仅在 `workflow-sync-check.sh` 内做路径解码：拒绝，无法保证其余依赖 changed files 的门禁一致。
- 临时放宽 workflow-sync：拒绝，会削弱“改代码必须联动文档”的核心约束。

## 版本影响
- 是否影响 API：否
- 是否影响事件模型：否
- 是否影响数据结构：否

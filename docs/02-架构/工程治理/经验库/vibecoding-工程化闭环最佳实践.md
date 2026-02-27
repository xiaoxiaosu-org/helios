# vibecoding 工程化闭环最佳实践（可迁移）

> 版本：v1.0
> 最近更新：2026-02-27
> 适用范围：新项目启动与既有项目治理升级
> 对应实现：`AGENTS.md`、`.githooks/*`、`.github/workflows/*`、`scripts/ci/*`、`scripts/docs/*`

## 0. 经验存储路径（本项目）

- 经验库固定路径：`docs/02-架构/工程治理/经验库/`
- 本文定位：把 HELIOS 的工程治理实践抽象成“新项目可直接复用”的启动框架。

---

## 1. 当前项目结构快照（截至 2026-02-27）

### 1.1 顶层结构

| 路径 | 作用 |
|---|---|
| `AGENTS.md` | 智能体/协作者统一入口（阅读顺序、硬不变量、门禁入口） |
| `docs/` | 系统记录（Docs-as-Code），按 `00-09` 固定语义分层 |
| `scripts/ci/` | 本地与 CI 质量门禁脚本（`verify.sh` 聚合入口） |
| `scripts/docs/` | 文档结构与治理一致性校验脚本 |
| `scripts/dev/` | 开发体验脚本（例如 hooks 安装） |
| `.githooks/` | pre-commit / commit-msg / pre-push 本地门禁 |
| `.github/workflows/` | `quality-gates.yml` + `doc-check.yml` 双工作流防绕过 |
| `artifacts/` | CAP 验收证据（可追溯产物） |

### 1.2 结构特征（对可迁移最关键）

1. 入口小而稳定：`AGENTS.md` 只保留“从哪里开始 + 去哪里找真相 + CI 强制什么”。
2. 规则细节下沉：复杂治理落在 `docs/02-架构/工程治理/`，避免入口膨胀。
3. 机械化优先：能脚本化就不靠“口头约定”，脚本再由 CI 强制。
4. 证据化交付：不仅要“通过”，还要能留下可复盘证据（`artifacts/`）。

---

## 2. Git 提交演进总结（截至 2026-02-27）

### 2.1 时间线

- 总提交：`16`（`main`）
- 起止日期：`2026-02-24` 到 `2026-02-27`
- 单日高峰：`2026-02-27`（12 次提交）

### 2.2 提交类型分布（按标题前缀）

- `chore`: 6
- `docs`: 4
- `ci`: 3
- `plan`: 1
- `fix`: 1
- `Initial commit`: 1

### 2.3 演进阶段（可复用模式）

1. 基线建立（2026-02-24 至 2026-02-25）：
   初始化仓库，建立 docs 治理与质量门禁基础。
2. 门禁收敛（2026-02-26）：
   CI 触发条件与 ADR 触发语义对齐，减少误报与漏报。
3. 闭环强化（2026-02-27）：
   渐进式文档导航、CAP 验收框架、hooks/模板/CI 一致性、main 分支保护与误拦截修复。

结论：该仓库不是“先写业务再补治理”，而是“先把工程闭环搭牢，再让后续迭代成本可控”。

---

## 3. 提炼出的 vibecoding 最佳实践（VIBE 闭环）

这里把可迁移要点压缩为 4 个动作。

### V: Verify-First（先验收入口）

1. 定义一个单一验证入口：例如 `scripts/ci/verify.sh`。
2. 验证入口必须可本地运行，不依赖 CI 才能知道结果。
3. 验证顺序固定：`lint -> typecheck -> test -> build -> coverage`。

### I: Index-as-Memory（文档索引就是长期记忆）

1. `docs/README.md` 只做任务分流。
2. 各域目录有 `README.md` 索引，内容多再分层。
3. 变更按语义入档（接口、事件、数据、领域、运行态、安全、ADR），禁止“散落在聊天记录里”。

### B: Boundary-as-Gate（边界即门禁）

1. 本地 hook 提前失败（pre-commit / commit-msg / pre-push）。
2. CI 做防绕过复核（即使本地 `--no-verify` 也拦得住）。
3. 对关键变更强制系统记录：
   - 架构/安全/兼容风险 => ADR
   - hotfix 分支 => 允许先 HOTFIX，再补 ADR

### E: Evidence-Driven（证据驱动）

1. 提交与 PR 强制结构化模板（功能、映射、原因、验证、影响）。
2. 输出必须“协作会话可见”，不要只藏在 hook/CI 日志。
3. 关键能力要有验收证据目录（例如 `artifacts/<CAP-ID>/<run-id>/`）。

---

## 4. 新项目快速落地（0 到闭环）

### T+0（第 1 天，2-4 小时）

1. 建立最小目录骨架：
   - `docs/00-术语表` ... `docs/09-ADR-架构决策`
   - `scripts/ci`、`scripts/docs`、`scripts/dev`
   - `.githooks`、`.github/workflows`
2. 建立三个入口：
   - `AGENTS.md`
   - `docs/README.md`
   - `scripts/ci/verify.sh`
3. 启用本地 hooks：
   - 统一安装脚本 `scripts/dev/install-git-hooks.sh`
4. 接入 CI 双门禁：
   - 质量门禁（lint/typecheck/test/build/coverage、secrets、debug print）
   - 文档与治理门禁（索引、规则一致性、ADR/HOTFIX）

### T+1（第 2-3 天）

1. 补齐提交模板和 PR 模板，并在 hook + CI 双处校验。
2. 把“关键变更触发 ADR”写入工作流规则，避免靠人工记忆。
3. 把“代码变更必须同步 docs”做成硬门禁。

### T+7（第一周）

1. 建立能力验收入口：`scripts/cap/verify.sh <CAP-ID>`（或等价）。
2. 至少固化 1 个 CAP（例如 PR 闭环自动化），从“规则文本”升级到“可执行能力”。
3. 补一份质量评分文档，明确下一周要补哪些短板。

---

## 5. 可直接复制的最小清单

### 必备文件

1. `AGENTS.md`
2. `docs/README.md`
3. `docs/02-架构/工程治理/工程治理与门禁.md`
4. `.github/workflows/quality-gates.yml`
5. `.github/workflows/doc-check.yml`
6. `.githooks/pre-commit`
7. `.githooks/commit-msg`
8. `.githooks/pre-push`
9. `scripts/dev/install-git-hooks.sh`
10. `scripts/ci/verify.sh`
11. `scripts/docs/index-check.sh`
12. `scripts/docs/git-governance-sync-check.sh`

### 必备规则

1. 入口文档短，细则文档全。
2. 关键规则必须“本地 + CI”双重约束。
3. 关键决策必须 ADR（hotfix 允许临时 HOTFIX）。
4. 业务/配置/SQL 变更必须同步更新 docs。
5. 禁止将关键过程只保留在聊天、口头或临时笔记中。

---

## 6. 常见失败模式与纠偏

1. 失败模式：规则只写文档，没人执行。  
   纠偏：每条关键规则都要有脚本校验入口。
2. 失败模式：只做本地 hook，CI 不兜底。  
   纠偏：同一规则至少有一条 CI 校验链。
3. 失败模式：只追求“能跑”，不保留证据。  
   纠偏：验收命令默认落盘产物，且命名可追溯。
4. 失败模式：新项目复制大量模板但不做裁剪。  
   纠偏：先上最小闭环，再按风险逐步加门禁。

---

## 7. 给“新开项目 + AI 编程工具” 的一句操作建议

先把“入口文档 + 验证脚本 + hook + CI + ADR”这 5 件事搭好，再开始让 AI 大规模改代码；否则生成速度越快，后续返工越大。

---

## 8. 配套文档

1. 命令版初始化清单（含 Git 配置）：`docs/02-架构/工程治理/经验库/vibecoding-新项目初始化命令清单.md`
2. 经验文档更新规则：`docs/02-架构/工程治理/经验库/经验文档更新规则.md`

# Git 门禁与模板对照清单

本清单用于回答三个问题：
- 这条 Git 规则在哪里实现？
- 文档是否有清晰描述？
- 是否有自动化约束防止后续漂移？

唯一信息源声明：
- 与 Git 门禁、Hook、模板、临时放宽、校验脚本链路相关的细项规则，以本文件为唯一信息源。
- `分支与门禁落地.md` 仅保留流程与操作步骤，不重复维护细项规则。

---

## 1. 门禁分层（实现视图）

1) 本地门禁（提前失败）
- `.githooks/pre-commit`
- `.githooks/commit-msg`
- `.githooks/pre-push`
- 安装入口：`scripts/dev/install-git-hooks.sh`

2) CI 门禁（防绕过）
- `/.github/workflows/doc-check.yml`
- `/.github/workflows/quality-gates.yml`

3) 模板（结构化输入）
- 提交模板：`/.github/commit_message_template.md`
- PR 模板：`/.github/pull_request_template.md`

4) 规则文档（系统记录）
- `AGENTS.md`
- `docs/02-架构/工程治理/工程治理与门禁.md`
- `docs/02-架构/工程治理/分支与门禁落地.md`（流程文档，不承载细项规则）

---

## 2. 对照矩阵（实现 ↔ 文档 ↔ 自动约束）

| 规则项 | 实现位置 | 文档位置 | 自动约束 |
|---|---|---|---|
| 禁止在 `main` 直接提交 | `.githooks/pre-commit` | 本文件 + `工程治理与门禁.md` | `scripts/docs/git-governance-sync-check.sh` |
| 提交标题格式校验 | `.githooks/commit-msg` + `doc-check.yml` | 本文件 + `AGENTS.md` + `工程治理与门禁.md` | hook + CI 双重校验 |
| 提交正文结构化段落校验 | `.githooks/commit-msg` + `doc-check.yml` | 本文件 + `AGENTS.md` + `工程治理与门禁.md` | hook + CI 双重校验 |
| 提交阶段打印结构化明细 | `.githooks/commit-msg` | 本文件 + `工程治理与门禁.md` | hook 日志输出 |
| 推送前打印结构化明细 | `.githooks/pre-push` | 本文件 + `工程治理与门禁.md` | hook 日志输出 |
| 推送前执行 docs 与 CI 校验 | `.githooks/pre-push` | 本文件 + `工程治理与门禁.md` | hook 强制执行 `index-check/rule-files-check/git-governance-sync-check/ci-verify` |
| PR 模板完整性与非空校验 | `doc-check.yml` | 本文件 + `工程治理与门禁.md` | CI 强制 |
| PR 阶段打印结构化明细 | `doc-check.yml` | 本文件 + `工程治理与门禁.md` | CI 日志输出 |
| `CODEOWNERS` 基线 | `quality-gates.yml` | 本文件 + `AGENTS.md` + `工程治理与门禁.md` | CI 强制 |
| secrets 扫描与 debug print 阻断 | `quality-gates.yml` | 本文件 + `AGENTS.md` + `工程治理与门禁.md` | CI 强制 |

---

## 3. 一致性强制规则（防止后续漂移）

脚本：`scripts/docs/git-governance-sync-check.sh`

强制校验以下一致性：
1) Hook 安装脚本必须声明并安装 `pre-commit/commit-msg/pre-push`。
2) `commit-msg` 的 `required_headers` 必须与提交模板段落一一对应。
3) `doc-check` 的 `required_sections` 必须与 PR 模板标题一一对应。
4) 治理文档必须覆盖关键门禁描述：
- hooks 名称与职责
- 关键本地脚本（`scripts/docs/index-check.sh` / `scripts/docs/rule-files-check.sh` / `scripts/docs/git-governance-sync-check.sh` / `scripts/ci/verify.sh`）
- CAP 验收入口（`scripts/cap/verify.sh CAP-00X`）
- 临时放宽变量（`HELIOS_ALLOW_COMMIT_MAIN`、`HELIOS_ALLOW_RELAXED_COMMIT_MSG`、`HELIOS_ALLOW_PUSH_MAIN`）
- CI 必选检查（`quality-gates`、`checks`）
- 文档职责分离（本文件承载细项、`分支与门禁落地.md` 只承载流程）

接入点：
- 本地：`.githooks/pre-push`
- CI：`.github/workflows/doc-check.yml`

---

## 4. 临时放宽策略（必须留痕）

允许的临时放宽变量：
- `HELIOS_ALLOW_COMMIT_MAIN=1`：仅放宽“main 直接提交”拦截
- `HELIOS_ALLOW_RELAXED_COMMIT_MSG=1`：仅放宽本次提交信息结构校验
- `HELIOS_ALLOW_PUSH_MAIN=1`：仅放宽本地 main 直推拦截（远端 ruleset 仍可拒绝）
- `git push --no-verify`：跳过本地 hook

使用要求：
- 仅紧急场景使用
- 必须在 PR 描述中说明原因、影响范围、补救措施

---

## 5. 维护约定

当你修改以下任一项时，必须同步更新另外两项：
- Hook/CI 实现
- 模板文件
- 本清单与治理文档

推荐顺序：
1) 先改模板（输入结构）
2) 再改校验（hook/CI）
3) 最后改文档与对照清单

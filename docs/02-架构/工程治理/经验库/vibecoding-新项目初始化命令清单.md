# vibecoding 新项目初始化命令清单（含 Git 配置）

> 版本：v1.1
> 最近更新：2026-02-27
> 适用范围：新项目 0->1 工程化启动（语言无关最小闭环）
> 对应实现：`.githooks/*`、`scripts/ci/*`、`scripts/docs/index-check.sh`、`.github/workflows/*`

## 0. 目标

在一个全新仓库中，用最少命令在 `1` 天内搭出“可执行、可验证、可审计”的工程闭环基线。

---

## 1. 一次性全局 Git 配置（建议）

首次配置机器时执行：

```bash
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
git config --global init.defaultBranch main
git config --global fetch.prune true
git config --global core.autocrlf input
git config --global rerere.enabled true
```

可选（希望默认 rebase 拉取时）：

```bash
git config --global pull.rebase true
git config --global rebase.autoStash true
```

---

## 2. T+0 初始化命令（可直接复制）

以下命令在新项目根目录执行。

```bash
# 1) 基础目录
mkdir -p docs/{00-术语表,01-产品,02-架构,03-领域模型,04-接口,05-事件,06-数据,07-运行态,08-安全,09-ADR-架构决策}
mkdir -p docs/02-架构/{工程治理,执行计划}
mkdir -p scripts/{ci,docs,dev}
mkdir -p .githooks .github/workflows .github

# 2) 最小入口文件
cat > AGENTS.md <<'EOF'
# 项目入口（最小版）
- 文档导航：docs/README.md
- 本地门禁：scripts/ci/verify.sh
- 关键约束：代码/配置/SQL 变更必须同步更新 docs/
EOF

cat > README.md <<'EOF'
# Project
- 入口：AGENTS.md
- 文档导航：docs/README.md
- 本地门禁：scripts/ci/verify.sh
EOF

cat > .github/commit_message_template.md <<'EOF'
feat(scope): 简要说明

功能:
- 本次功能点

功能与文件映射:
- 功能A: path/a path/b

涉及文件:
- path/a
- path/b

主要改动:
- 关键改动说明

为什么改:
- 背景与目标

验证:
- 执行命令与结果
EOF

cat > docs/README.md <<'EOF'
# 文档导航
- 术语：docs/00-术语表/README.md
- 产品：docs/01-产品/README.md
- 架构：docs/02-架构/README.md
- 领域：docs/03-领域模型/README.md
- 接口：docs/04-接口/README.md
- 事件：docs/05-事件/README.md
- 数据：docs/06-数据/README.md
- 运行态：docs/07-运行态/README.md
- 安全：docs/08-安全/README.md
- ADR：docs/09-ADR-架构决策/README.md
EOF

# 3) 顶层索引占位（每个目录必须有 README）
for d in docs/00-术语表 docs/01-产品 docs/02-架构 docs/03-领域模型 docs/04-接口 docs/05-事件 docs/06-数据 docs/07-运行态 docs/08-安全 docs/09-ADR-架构决策; do
  test -f "$d/README.md" || cat > "$d/README.md" <<EOF
# $(basename "$d")（索引）
EOF
done

# 4) ADR 基础文件
cat > docs/09-ADR-架构决策/ADR-模板.md <<'EOF'
# ADR-YYYYMMDD-标题
## 状态
## 背景
## 决策
## 影响
## 回滚/替代
EOF

cat > docs/09-ADR-架构决策/ADR-索引.md <<'EOF'
# ADR 索引
EOF

cat > .github/CODEOWNERS <<'EOF'
* @your-org/your-team
EOF
```

---

## 3. Git 与 Hook 本仓库级配置（必须）

```bash
# 1) 本地 hooks + commit template 指向项目文件
cat > scripts/dev/install-git-hooks.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
git config core.hooksPath .githooks
git config commit.template "$(pwd)/.github/commit_message_template.md"
chmod +x .githooks/pre-commit .githooks/commit-msg .githooks/pre-push
echo "hooks/template installed"
EOF
chmod +x scripts/dev/install-git-hooks.sh

# 2) pre-commit：禁止 main 直提（可按需保留放宽变量）
cat > .githooks/pre-commit <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
if [ "$branch" = "main" ] && [ "${ALLOW_COMMIT_MAIN:-0}" != "1" ]; then
  echo "禁止在 main 直接提交，请走分支 + PR。"
  exit 1
fi
EOF

# 3) commit-msg：最小标题规范
cat > .githooks/commit-msg <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
msg_file="$1"
subject="$(sed -n '1p' "$msg_file" | tr -d '\r')"
regex='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([[:alnum:]./_-]+\))?!?: .{1,72}$'
echo "$subject" | grep -Eq "$regex" || {
  echo "提交标题必须为: type(scope): summary"
  exit 1
}
EOF

# 4) pre-push：推送前强制本地验证
cat > .githooks/pre-push <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
scripts/docs/index-check.sh
scripts/ci/verify.sh
EOF

chmod +x .githooks/pre-commit .githooks/commit-msg .githooks/pre-push
./scripts/dev/install-git-hooks.sh
```

---

## 4. CI 门禁最小模板（必须）

```bash
# 质量门禁聚合入口
cat > scripts/ci/verify.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
scripts/ci/lint.sh
scripts/ci/typecheck.sh
scripts/ci/test.sh
scripts/ci/build.sh
scripts/ci/coverage-check.sh
EOF
chmod +x scripts/ci/verify.sh

# 质量门禁占位脚本（新项目可先占位，后续替换为真实命令）
for f in lint.sh typecheck.sh test.sh build.sh coverage-check.sh; do
  cat > "scripts/ci/${f}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "[ci] placeholder passed"
EOF
  chmod +x "scripts/ci/${f}"
done

# docs 索引校验最小脚本
cat > scripts/docs/index-check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
for d in docs/00-术语表 docs/01-产品 docs/02-架构 docs/03-领域模型 docs/04-接口 docs/05-事件 docs/06-数据 docs/07-运行态 docs/08-安全 docs/09-ADR-架构决策; do
  test -d "$d" || { echo "missing dir: $d"; exit 1; }
  ls "$d"/*.md >/dev/null 2>&1 || { echo "missing index md: $d"; exit 1; }
done
test -f docs/README.md || { echo "missing docs/README.md"; exit 1; }
EOF
chmod +x scripts/docs/index-check.sh

# 最小 CI workflows（先保证可执行，后续按技术栈加严）
cat > .github/workflows/quality-gates.yml <<'EOF'
name: quality-gates
on: [push, pull_request]
jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: scripts/ci/verify.sh
EOF

cat > .github/workflows/doc-check.yml <<'EOF'
name: checks
on: [push, pull_request]
jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: scripts/docs/index-check.sh
EOF
```

`.github/workflows` 建议最少两个工作流：

1. `quality-gates.yml`：执行构建/测试/覆盖率、secrets 扫描、debug print 阻断。  
2. `doc-check.yml`：执行 docs 索引完整性、ADR/HOTFIX、模板规范、Git 治理一致性校验。

---

## 5. 第一次提交前检查

```bash
./scripts/dev/install-git-hooks.sh
scripts/docs/index-check.sh
scripts/ci/verify.sh
git status --short
```

通过后再首提：

```bash
git checkout -b chore/bootstrap-governance
git add .
git commit -m "chore(init): 初始化工程闭环基线"
```

---

## 6. GitHub 远端保护配置（仓库设置）

对 `main` 分支至少开启：

1. 禁止直接 push（仅允许 PR 合并）。
2. Require status checks（至少勾选 `quality-gates`、`checks`）。
3. Require pull request reviews（至少 1 人）。
4. CODEOWNERS 评审（如果仓库启用该项）。

说明：本地 hook 只能“提前失败”，真正防绕过依赖远端保护规则。

---

## 7. 新项目接入 AI 编程工具时的开场指令（建议）

在项目根目录首条指令固定为：

```text
先阅读 AGENTS.md 和 docs/README.md；所有代码/配置/SQL 变更必须同步 docs；
提交前必须通过 scripts/ci/verify.sh 和 scripts/docs/index-check.sh。
```

这条指令会显著降低“AI 只改代码不补档”的回归概率。

---

## 8. 交给大模型的最小文件包（建议）

至少提供以下文件给大模型作为启动上下文：

1. `AGENTS.md`
2. `README.md`
3. `docs/README.md`
4. `docs/09-ADR-架构决策/ADR-模板.md`
5. `scripts/ci/verify.sh`
6. `scripts/docs/index-check.sh`
7. `.githooks/pre-commit`
8. `.githooks/commit-msg`
9. `.githooks/pre-push`
10. `.github/workflows/quality-gates.yml`
11. `.github/workflows/doc-check.yml`

给模型的固定要求建议附加：

```text
先跑 scripts/docs/index-check.sh 和 scripts/ci/verify.sh；
失败则先修脚本与目录，不允许跳过；
任何代码变更必须同步 docs，并在提交信息里写验证结果。
```

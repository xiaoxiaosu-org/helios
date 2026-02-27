#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[hooks] $*"
}

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${root}"

if ! command -v git >/dev/null 2>&1; then
  log "未找到 git 命令。"
  exit 3
fi

hooks_path=".githooks"
required_hooks=(
  "${hooks_path}/pre-commit"
  "${hooks_path}/pre-push"
  "${hooks_path}/commit-msg"
)

missing=0
for hook in "${required_hooks[@]}"; do
  if [ ! -f "${hook}" ]; then
    log "缺少 hook 文件：${hook}"
    missing=1
  fi
done

if [ "${missing}" -ne 0 ]; then
  exit 3
fi

for hook in "${required_hooks[@]}"; do
  chmod +x "${hook}"
done

current="$(git config --get core.hooksPath || true)"
if [ -n "${current}" ] && [ "${current}" != "${hooks_path}" ]; then
  log "检测到已配置 core.hooksPath=${current}"
  log "将覆盖为：${hooks_path}"
fi

git config core.hooksPath "${hooks_path}"

template_rel=".github/commit_message_template.md"
template_abs="${root}/${template_rel}"
if [ -f "${template_abs}" ]; then
  git config commit.template "${template_abs}"
else
  log "缺少提交模板文件：${template_rel}"
  exit 3
fi

log "已启用 hooks：core.hooksPath=${hooks_path}"
log "已启用提交模板：commit.template=${template_abs}"
log "提示：紧急情况下可用 git push --no-verify 临时跳过（需在 PR 说明原因）。"
log "卸载：git config --unset core.hooksPath && git config --unset commit.template"
log "已安装 hooks：$(printf \"%s \" \"${required_hooks[@]}\")"

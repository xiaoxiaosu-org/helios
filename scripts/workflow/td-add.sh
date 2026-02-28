#!/usr/bin/env bash
set -euo pipefail

echo "[workflow] scripts/workflow/td-add.sh 已废弃，不再兼容历史 TD 模型。" >&2
echo "[workflow] 请改用：scripts/workflow/workitem-add.sh --plan-id PLAN-YYYYMMDD-NN ..." >&2
exit 1

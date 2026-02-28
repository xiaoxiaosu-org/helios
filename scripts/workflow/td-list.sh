#!/usr/bin/env bash
set -euo pipefail

echo "[workflow] scripts/workflow/td-list.sh 已废弃，不再兼容历史 TD 视图。" >&2
echo "[workflow] 请改用：scripts/workflow/workitem-list.sh [todo|in_progress|blocked|done|all]" >&2
exit 1

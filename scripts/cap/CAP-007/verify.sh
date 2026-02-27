#!/usr/bin/env bash
set -euo pipefail

f="docs/02-架构/技术债清单.md"
test -f "${f}" || exit 1

if ! rg -n "TD-[0-9]{3}" "${f}" >/dev/null; then
  exit 1
fi

{
  echo "ok: ${f}"
} > "${ARTIFACT_DIR}/tech-debt-check.txt"


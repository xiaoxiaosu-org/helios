#!/usr/bin/env bash
set -euo pipefail

f="docs/02-架构/质量评分与演进.md"
test -f "${f}" || exit 1

grep -q "## 评分维度" "${f}" || exit 1
grep -q "## 当前现状" "${f}" || exit 1
grep -q "## 下一步" "${f}" || exit 1

{
  echo "ok: ${f}"
} > "${ARTIFACT_DIR}/quality-score-check.txt"


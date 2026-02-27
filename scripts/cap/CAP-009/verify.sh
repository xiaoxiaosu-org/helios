#!/usr/bin/env bash
set -euo pipefail

tmpl=""
if [ -f .github/pull_request_template.md ]; then
  tmpl=".github/pull_request_template.md"
elif [ -f .github/PULL_REQUEST_TEMPLATE.md ]; then
  tmpl=".github/PULL_REQUEST_TEMPLATE.md"
fi

if [ -z "${tmpl}" ]; then
  echo "[CAP-009] missing PR template (.github/pull_request_template.md or .github/PULL_REQUEST_TEMPLATE.md)" >&2
  exit 2
fi

grep -q "\\[ \\]" "${tmpl}" || exit 1
grep -q "docs" "${tmpl}" || exit 1
grep -q "ADR" "${tmpl}" || exit 1

{
  echo "ok: ${tmpl}"
} > "${ARTIFACT_DIR}/pr-template-check.txt"


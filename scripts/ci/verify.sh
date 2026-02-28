#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
source "${here}/_lib.sh"

ci_begin "CI 门禁聚合（verify）"

ci_run "${here}/gate-selftest.sh"
ci_run "${here}/workflow-sync-check.sh"
ci_run "${here}/tech-debt-governance-check.sh"
ci_run "${here}/arch-check.sh"
ci_run "${here}/lint.sh"
ci_run "${here}/typecheck.sh"
ci_run "${here}/test.sh"
ci_run "${here}/build.sh"
ci_run "${here}/coverage-check.sh"

#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

"${here}/lint.sh"
"${here}/typecheck.sh"
"${here}/test.sh"
"${here}/build.sh"
"${here}/coverage-check.sh"


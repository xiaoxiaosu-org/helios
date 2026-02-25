#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

THRESHOLD="${COVERAGE_THRESHOLD:-80}"
log "coverage gate start (threshold=${THRESHOLD}%)"

if ! has_any_code_dir; then
  log "no business code stack detected, skip coverage check"
  exit 0
fi

if [ -f coverage/coverage-summary.json ]; then
  pct=$(python3 - <<'PY'
import json
with open('coverage/coverage-summary.json', encoding='utf-8') as f:
    data = json.load(f)
print(data.get('total', {}).get('lines', {}).get('pct', 0))
PY
)
  log "line coverage=${pct}%"
  python3 - <<PY
pct=float('${pct}')
threshold=float('${THRESHOLD}')
raise SystemExit(0 if pct >= threshold else 1)
PY
  exit 0
fi

if [ -f coverage.xml ]; then
  pct=$(python3 - <<'PY'
import xml.etree.ElementTree as ET
root = ET.parse('coverage.xml').getroot()
rate = root.attrib.get('line-rate')
if rate is None:
    print(0)
else:
    print(float(rate)*100)
PY
)
  log "line coverage=${pct}%"
  python3 - <<PY
pct=float('${pct}')
threshold=float('${THRESHOLD}')
raise SystemExit(0 if pct >= threshold else 1)
PY
  exit 0
fi

jacoco_xml=$(find . -path '*/jacoco*.xml' | head -n 1 || true)
if [ -n "${jacoco_xml}" ]; then
  pct=$(python3 - <<PY
import xml.etree.ElementTree as ET
root = ET.parse('${jacoco_xml}').getroot()
for c in root.findall('counter'):
    if c.attrib.get('type') == 'LINE':
        missed = int(c.attrib.get('missed', 0))
        covered = int(c.attrib.get('covered', 0))
        total = missed + covered
        print(0 if total == 0 else covered * 100.0 / total)
        break
else:
    print(0)
PY
)
  log "line coverage=${pct}% (${jacoco_xml})"
  python3 - <<PY
pct=float('${pct}')
threshold=float('${THRESHOLD}')
raise SystemExit(0 if pct >= threshold else 1)
PY
  exit 0
fi

log "未发现覆盖率报告（coverage/coverage-summary.json、coverage.xml、jacoco*.xml）。请在 scripts/ci/test.sh 生成覆盖率产物。"
exit 1

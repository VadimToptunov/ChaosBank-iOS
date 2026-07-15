#!/bin/bash
#
# Runs the unit tests with coverage and enforces a threshold on the LOGIC layer
# (Core, Models, view models, backend). SwiftUI View bodies and the network price
# service are excluded — they are exercised by UI tests, not unit tests, so they
# are not part of the unit-coverage budget.
#
# Usage:  Scripts/coverage.sh [threshold]      (default 95)
# Env:    DEST   xcodebuild -destination (default: iPhone 17 simulator)
#
set -euo pipefail

THRESHOLD="${1:-95}"
DEST="${DEST:-platform=iOS Simulator,name=iPhone 17}"
PROJECT="ChaosBank.xcodeproj"
SCHEME="ChaosBank"
RB="$(mktemp -d)/result.xcresult"

# Files excluded from the unit-coverage budget (UI views + network).
EXCLUDE='View\.swift$|AuthViews|WebLoginView|Components\.swift|Sparkline|LiveTicker|A11y\.swift|Colors\.swift|BuildBadge|LivePriceService'

echo "› Running tests with coverage ($DEST)…"
xcodebuild test \
  -project "$PROJECT" -scheme "$SCHEME" \
  -destination "$DEST" \
  -enableCodeCoverage YES -resultBundlePath "$RB" \
  -quiet

xcrun xccov view --report "$RB" 2>/dev/null | grep -E "ChaosBank/.*\.swift" > "$RB.txt" || true

python3 - "$RB.txt" "$THRESHOLD" "$EXCLUDE" <<'PY'
import re, sys
report, threshold, exclude = sys.argv[1], float(sys.argv[2]), sys.argv[3]
cov = tot = 0
under = []
for line in open(report):
    m = re.search(r'/ChaosBank/(.+?\.swift).*?\((\d+)/(\d+)\)', line)
    if not m: continue
    path, c, t = m.group(1), int(m.group(2)), int(m.group(3))
    if re.search(exclude, path): continue
    cov += c; tot += t
    pct = 100 * c / t if t else 100
    if pct < threshold: under.append((pct, path, c, t))
overall = 100 * cov / tot if tot else 100
print(f"\nLOGIC-LAYER COVERAGE: {overall:.1f}%  ({cov}/{tot})  threshold {threshold:.0f}%")
for pct, p, c, t in sorted(under):
    print(f"  under: {pct:5.1f}%  {p}  ({c}/{t})")
if overall + 1e-9 < threshold:
    print(f"\n✗ below threshold ({overall:.1f}% < {threshold:.0f}%)")
    sys.exit(1)
print("\n✓ coverage gate passed")
PY

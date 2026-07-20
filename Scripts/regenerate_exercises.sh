#!/bin/bash
# Regenerate exercises.json from the in-app catalog (the single source of truth).
# The simulator sandbox can't write to the repo, so we run the dump test and
# capture the JSON it prints between markers. Run this after adding/removing a defect.
set -euo pipefail
cd "$(dirname "$0")/.."

DEST="${DEST:-platform=iOS Simulator,name=iPhone 17}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

xcodebuild test \
  -project ChaosBank.xcodeproj -scheme ChaosBank \
  -destination "$DEST" \
  -only-testing:ChaosBankTests/FinalCoverageTests/testDumpExercisesCatalog \
  >"$LOG" 2>&1 || { tail -40 "$LOG"; echo "build/test failed"; exit 1; }

python3 - "$LOG" <<'PY'
import re, sys
log = open(sys.argv[1], errors="ignore").read()
m = re.search(r"<<<EXERCISES_JSON_BEGIN>>>\n(.*?)\n<<<EXERCISES_JSON_END>>>", log, re.S)
if not m:
    sys.exit("marker block not found in test output")
open("exercises.json", "w").write(m.group(1).rstrip("\n") + "\n")
print("wrote exercises.json")
PY

python3 Scripts/check_exercises.py exercises.json IOS

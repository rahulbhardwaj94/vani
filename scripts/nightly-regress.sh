#!/bin/bash
# Nightly regression run. Executed by launchd from the staged copy in
# ~/Library/Application Support/Vani/regress (deployed by
# scripts/install-nightly.sh — launchd can't read ~/Documents, so nothing
# here may touch the repo). Runs the prebuilt harness over the staged
# fixtures plus the personal corpus, appends the report to regress.log,
# and raises a notification if anything regressed.
set -uo pipefail
cd "$(dirname "$0")"

LOG="$HOME/Library/Application Support/Vani/regress.log"
mkdir -p "$(dirname "$LOG")"
# Keep the log bounded (~last 200 KB).
[ -f "$LOG" ] && [ "$(stat -f%z "$LOG")" -gt 200000 ] && tail -c 100000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"

{
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="
  ./VaniRegress
  status=$?
  echo "exit: $status"
} >> "$LOG" 2>&1

if [ "${status:-1}" -ne 0 ]; then
  osascript -e 'display notification "A fixture regressed — see regress.log" with title "Vani nightly regression FAILED" sound name "Basso"' || true
fi
exit "${status:-1}"

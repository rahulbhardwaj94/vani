#!/bin/bash
# Deploys the nightly regression job. launchd background processes cannot
# read ~/Documents (TCC), so this stages everything the run needs — the
# release VaniRegress binary, the fixtures, and the runner script — into
# ~/Library/Application Support/Vani/regress and points a launchd agent
# there (02:30 nightly). Models are already under Application Support
# (TranscriptionService.modelsBase). Re-run this script after changing the
# engine or fixtures to deploy the new build.
#
# Uninstall:
#   launchctl bootout gui/$(id -u)/com.rahulbhardwaj.vani.regress
#   rm ~/Library/LaunchAgents/com.rahulbhardwaj.vani.regress.plist
set -euo pipefail
cd "$(dirname "$0")/.."

STAGE="$HOME/Library/Application Support/Vani/regress"
PLIST="$HOME/Library/LaunchAgents/com.rahulbhardwaj.vani.regress.plist"
LABEL="com.rahulbhardwaj.vani.regress"

[ -e fixtures/s1-ramble.wav ] || ./scripts/gen-fixtures.sh
swift build -c release --product VaniRegress

mkdir -p "$STAGE"
cp .build/release/VaniRegress "$STAGE/"
rm -rf "$STAGE/fixtures"
cp -R fixtures "$STAGE/fixtures"
cp scripts/nightly-regress.sh "$STAGE/nightly-regress.sh"
chmod +x "$STAGE/nightly-regress.sh" "$STAGE/VaniRegress"

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${STAGE}/nightly-regress.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>2</integer><key>Minute</key><integer>30</integer></dict>
  <key>WorkingDirectory</key><string>${STAGE}</string>
  <key>StandardOutPath</key><string>/tmp/vani-regress-launchd.log</string>
  <key>StandardErrorPath</key><string>/tmp/vani-regress-launchd.log</string>
  <key>ProcessType</key><string>Standard</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl print "gui/$(id -u)/${LABEL}" >/dev/null && echo "installed: nightly regression at 02:30, staged in ${STAGE}"
echo "run now to verify: launchctl kickstart gui/$(id -u)/${LABEL}"

#!/usr/bin/env bash
# Release automation: build the signed app, zip it, create a GitHub release,
# and print the sha256 + cask stanza for the Homebrew tap
# (github.com/rahulbhardwaj94/homebrew-tap).
#
# Usage: ./scripts/release.sh <version> [notes-file]
#   ./scripts/release.sh 0.2.0 /tmp/notes.md
#
# Prereqs: gh authenticated; CFBundleShortVersionString already bumped in
# Resources/Info.plist (the script refuses to ship a mismatched version).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: release.sh <version> [notes-file]}"
NOTES="${2:-}"

PLIST_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
if [[ "$PLIST_VERSION" != "$VERSION" ]]; then
    echo "error: Info.plist says $PLIST_VERSION but releasing $VERSION — bump the plist first." >&2
    exit 1
fi

./scripts/test.sh
./scripts/build-app.sh

ZIP="build/Vani-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent build/Vani.app "$ZIP"
SHA256=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)

echo "==> Creating GitHub release v$VERSION"
if [[ -n "$NOTES" ]]; then
    gh release create "v$VERSION" "$ZIP" --title "Vani $VERSION" --notes-file "$NOTES"
else
    gh release create "v$VERSION" "$ZIP" --title "Vani $VERSION" --generate-notes
fi

cat <<EOF

==> Done. For homebrew-tap/Casks/vani.rb:
    version "$VERSION"
    sha256 "$SHA256"
EOF

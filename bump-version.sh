#!/usr/bin/env bash
# Bumps the patch version in control and Info.plist.
# Usage: ./bump-version.sh [--commit]
#   --commit  Also commit the change with [skip ci]
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTROL="$PROJECT_DIR/control"
PLIST="$PROJECT_DIR/Resources/Info.plist"

# Read current version from control
CURRENT=$(grep '^Version: ' "$CONTROL" | sed 's/^Version: //')
BASE="${CURRENT%%-*}"  # strip -test suffix if present

# Increment the number after the dot (e.g. 1.0 → 1.1, 1.9 → 1.10)
MAJOR="${BASE%.*}"
MINOR="${BASE#*.}"
NEW_MINOR=$((MINOR + 1))
NEW_VERSION="${MAJOR}.${NEW_MINOR}"

echo "Bumping version: ${CURRENT} → ${NEW_VERSION}"

# Update control
sed -i "s/^Version: .*/Version: ${NEW_VERSION}/" "$CONTROL"

# Update Info.plist (both CFBundleShortVersionString and CFBundleVersion)
sed -i '/<key>CFBundleShortVersionString<\/key>/{n;s|<string>.*</string>|<string>'"${NEW_VERSION}"'</string>|}' "$PLIST"
sed -i '/<key>CFBundleVersion<\/key>/{n;s|<string>.*</string>|<string>'"${NEW_VERSION}"'</string>|}' "$PLIST"

echo "Updated:"
echo "  control       → Version: ${NEW_VERSION}"
echo "  Info.plist    → CFBundleShortVersionString: ${NEW_VERSION}"
echo "  Info.plist    → CFBundleVersion: ${NEW_VERSION}"

if [ "${1:-}" = "--commit" ]; then
    git -C "$PROJECT_DIR" add control Resources/Info.plist
    git -C "$PROJECT_DIR" commit -m "Bump version to ${NEW_VERSION} [skip ci]"
    echo "Committed as: $(git -C "$PROJECT_DIR" rev-parse HEAD)"
fi

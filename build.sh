#!/bin/bash
# build.sh — produce dist/mhealth-installer.pkg
#
# Two-step build:
#   1. pkgbuild     → flat component pkg (with payload + postinstall scripts)
#   2. productbuild → distribution pkg (welcome/conclusion, OS version check)
#
# Optional signing — set DEVELOPER_ID to an installer signing identity:
#     export DEVELOPER_ID="Developer ID Installer: Your Name (TEAMID)"
#     ./build.sh
# Without DEVELOPER_ID, the pkg is unsigned — teammates will see a Gatekeeper
# warning on first open. Workaround: right-click → Open, then "Open" in the prompt.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

VERSION="${VERSION:-1.0.0}"
IDENTIFIER="com.mhealth.tools"
COMPONENT_PKG="build/mhealth-tools.pkg"
FINAL_PKG="dist/mhealth-installer.pkg"

DEVELOPER_ID="${DEVELOPER_ID:-}"

rm -rf build
mkdir -p build dist

# Drop a VERSION marker into the payload so installed machines can `cat /usr/local/mhealth/VERSION`
echo "$VERSION" > payload/usr/local/mhealth/VERSION

echo "→ Step 1/2: pkgbuild"
pkgbuild \
  --root payload \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  --install-location / \
  --scripts scripts \
  "$COMPONENT_PKG"

echo "→ Step 2/2: productbuild"
PRODUCT_ARGS=(
  --distribution distribution.xml
  --resources Resources
  --package-path build
  --version "$VERSION"
)
if [ -n "$DEVELOPER_ID" ]; then
  PRODUCT_ARGS+=(--sign "$DEVELOPER_ID")
  echo "  (signing with: $DEVELOPER_ID)"
else
  echo "  (unsigned — teammates will see Gatekeeper warning on first open)"
fi

productbuild "${PRODUCT_ARGS[@]}" "$FINAL_PKG"

echo ""
echo "✓ Built $FINAL_PKG ($(du -h "$FINAL_PKG" | awk '{print $1}'))"
echo ""
echo "Verify:"
echo "  pkgutil --payload-files $FINAL_PKG | head -30"
echo ""
if [ -z "$DEVELOPER_ID" ]; then
cat <<EOF
Distribution notes (unsigned build):
  • Share via Slack / Dropbox / internal share.
  • First-time install on each teammate's Mac will show a Gatekeeper warning.
    Workaround: Finder → right-click → Open, then click "Open" in the prompt.
    Or: System Settings → Privacy & Security → "Open Anyway"
  • Subsequent installs of the same package are unblocked.

To remove the warning entirely, sign with a Developer ID:
  export DEVELOPER_ID="Developer ID Installer: Your Name (TEAMID)"
  ./build.sh
EOF
fi

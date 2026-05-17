#!/bin/bash
# mhealth one-paste installer for Aveosoft teammates.
#
# Run via:
#     curl -fsSL https://raw.githubusercontent.com/jcaveo/mhealth-installer/main/install.sh | bash
#
# (If repo is private, save this file from Slack/email and run:  bash install.sh)
#
# Does:
#   1. Install Homebrew if missing  (you MUST be on macOS)
#   2. Install Homebrew Python if missing  (avoids the Apple Python TCC bug)
#   3. Download the latest mhealth-installer.pkg from the GitHub release
#   4. Open it for you to install (Gatekeeper prompt → right-click Open)
#
# If you've already installed the .pkg and just need to fix the Python:
#     brew install python && mhealth-setup

set -e

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()    { echo -e "${GREEN}✓${NC} $*"; }
note()  { echo -e "${BLUE}→${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
die()   { echo -e "${RED}✗${NC} $*" >&2; exit 1; }

[ "$(uname)" = "Darwin" ] || die "macOS only."

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  mhealth — one-paste installer"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ── Step 1: Homebrew ────────────────────────────────────────────────────
if command -v brew >/dev/null 2>&1; then
  ok "Homebrew already installed ($(brew --version | head -1))"
else
  note "Homebrew not found. Installing — this needs your sudo password..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  command -v brew >/dev/null 2>&1 || die "Homebrew install failed."
  ok "Homebrew installed"
fi

# ── Step 2: Homebrew Python ────────────────────────────────────────────
BREW_PREFIX="$(brew --prefix)"
BREW_PYTHON="$BREW_PREFIX/bin/python3"

if [ -x "$BREW_PYTHON" ] && ! readlink "$BREW_PYTHON" 2>/dev/null | grep -q "CommandLineTools"; then
  ok "Homebrew Python already installed ($($BREW_PYTHON --version))"
else
  note "Installing Homebrew Python (this is what makes folder scanning actually work)..."
  brew install python
  ok "Homebrew Python installed ($($BREW_PYTHON --version))"
fi

# ── Step 3: Download the pkg ───────────────────────────────────────────
PKG_URL="${MHEALTH_PKG_URL:-https://github.com/jcaveo/mhealth-installer/raw/main/dist/mhealth-installer.pkg}"
TMP_PKG="/tmp/mhealth-installer-$(date +%s).pkg"

note "Downloading mhealth-installer.pkg from:"
echo "    $PKG_URL"
if ! curl -fsSL -o "$TMP_PKG" "$PKG_URL"; then
  warn "Direct download failed. The repo may be private."
  warn "Save mhealth-installer.pkg from Slack/email, then double-click it to install."
  exit 1
fi
SIZE_KB=$(($(wc -c < "$TMP_PKG") / 1024))
ok "Downloaded ($SIZE_KB KB)"

# ── Step 4: Run the installer ──────────────────────────────────────────
note "Opening the installer. Click through:"
echo "    1. 'Open' in the Gatekeeper warning (it's unsigned)"
echo "    2. Enter your admin password when prompted"
echo "    3. Click Install"
echo ""
note "After install, dashboard auto-opens at http://127.0.0.1:8765/"
echo ""
open "$TMP_PKG"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Setup complete. The installer is open — follow its prompts."
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Next steps after install:"
echo "  • Open http://127.0.0.1:8765/"
echo "  • For Cloud Archive (optional): see Cloud Setup tab for"
echo "    one-click recipes (R2 / Drive / Mega / Dropbox / etc.)"
echo "  • For folder scanning under ~/Documents, ~/Desktop, ~/Downloads:"
echo "    grant Full Disk Access — the dashboard's Archive tab walks"
echo "    you through it when first needed."
echo ""

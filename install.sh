#!/usr/bin/env bash
# SidePiece beta installer. One line:
#   curl -fsSL https://sidepiece.onrender.com/install.sh | bash
# Downloads the latest beta DMG, installs to /Applications, clears the
# quarantine flag (unsigned beta - skips the "Open Anyway" dance), launches.
set -euo pipefail

DMG_URL="https://github.com/arbonomous/sidepiece-site/releases/download/beta-1/SidePiece.dmg"
APP="SidePiece.app"
DEST="/Applications/$APP"
TMP="$(mktemp -d)"
MNT="$TMP/mnt"

cleanup() {
  hdiutil detach "$MNT" -quiet 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

step() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "SidePiece is a macOS app; this installer only runs on a Mac."

step "Downloading the latest SidePiece beta"
curl -fsSL "$DMG_URL" -o "$TMP/SidePiece.dmg" || fail "Download failed. Check your connection and try again ($DMG_URL)."

step "Mounting the DMG"
mkdir -p "$MNT"
hdiutil attach "$TMP/SidePiece.dmg" -nobrowse -readonly -mountpoint "$MNT" -quiet || fail "Could not mount the downloaded DMG (it may be truncated; try again)."
[ -d "$MNT/$APP" ] || fail "$APP not found inside the DMG - the release asset looks wrong. Please report this to arbonomous@proton.me."

if pgrep -x SidePiece > /dev/null 2>&1; then
  step "SidePiece is running - asking it to quit"
  osascript -e 'tell application "SidePiece" to quit' 2>/dev/null || true
  for _ in 1 2 3 4 5; do
    if ! pgrep -x SidePiece > /dev/null 2>&1; then break; fi
    sleep 1
  done
  if pgrep -x SidePiece > /dev/null 2>&1; then
    fail "SidePiece is still running. Quit it first (right-click its Dock icon > Quit), then re-run this command."
  fi
fi

step "Installing to /Applications"
if [ -d "$DEST" ]; then
  rm -rf "$DEST" || fail "Could not replace the old copy at $DEST. Re-run as: curl -fsSL https://sidepiece.onrender.com/install.sh | sudo bash"
fi
cp -R "$MNT/$APP" "$DEST" || fail "Copy to /Applications failed. Re-run as: curl -fsSL https://sidepiece.onrender.com/install.sh | sudo bash"
[ -x "$DEST/Contents/MacOS/SidePiece" ] || fail "Copy looks incomplete ($DEST has no executable). Please report this to arbonomous@proton.me."

step "Clearing the macOS quarantine flag (unsigned beta)"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
if xattr "$DEST" 2>/dev/null | grep -q 'com.apple.quarantine'; then
  fail "Could not clear the quarantine flag. Run: sudo xattr -dr com.apple.quarantine $DEST"
fi

step "Launching SidePiece"
open "$DEST" || fail "Installed fine, but launch failed - open $DEST manually from Applications."

printf '\033[1;32mDone!\033[0m SidePiece is installed. Touch the edge of your screen and Telegram slides out.\n'

# Anonymous install count: fetch a 1-byte file so GitHub counts one download. No IDs, no data sent.
curl -fsSL -o /dev/null --max-time 5 "https://github.com/arbonomous/sidepiece-site/releases/download/beta-1/install-ping.txt" 2>/dev/null || true

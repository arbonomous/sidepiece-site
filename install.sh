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
    # A duplicate copy (e.g. launched from Downloads) may be the one still
    # running; osascript quit by name only reaches one instance.
    pkill -f 'SidePiece.app/Contents/MacOS/SidePiece' 2>/dev/null || true
    sleep 1
  fi
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

step "Checking the macOS quarantine flag (unsigned beta)"
# macOS 26's xattr can reject the old recursive -r flag. The app bundle root
# is the installer's first-run Gatekeeper check; never ignore a failed clear.
if xattr -p com.apple.quarantine "$DEST" >/dev/null 2>&1; then
  xattr -d com.apple.quarantine "$DEST" || true
  if xattr -p com.apple.quarantine "$DEST" >/dev/null 2>&1; then
    fail "The installed app is still quarantined. Open SidePiece from Applications, then in System Settings > Privacy & Security click Open Anyway. Installation is complete, but the one-line launch could not clear this macOS security prompt."
  fi
fi

step "Checking for duplicate copies"
# Older installs can live in Downloads/Desktop/etc. The Dock may keep launching
# such a copy even after /Applications is updated. Move every copy other than
# /Applications/SidePiece.app to the Trash. App data lives in ~/Library, not in
# the bundle, so this is safe; no-op when nothing extra is found.
if command -v mdfind > /dev/null 2>&1; then
  while IFS= read -r dupe; do
    [ "$dupe" = "$DEST" ] && continue
    case "$dupe" in "$HOME/.Trash/"*|/Volumes/*|"$MNT"*|/private/var/*) continue;; esac
    [ -d "$dupe" ] || continue
    target="$HOME/.Trash/SidePiece.app"
    n=1
    while [ -e "$target" ]; do target="$HOME/.Trash/SidePiece $n.app"; n=$((n+1)); done
    if mv "$dupe" "$target" 2> /dev/null; then
      echo "  Moved old copy to the Trash: $dupe"
    fi
  done < <(mdfind "kMDItemCFBundleIdentifier == 'com.sidepiece.app'" 2>/dev/null)
fi
killall Dock 2>/dev/null || true

step "Launching SidePiece"
open "$DEST" || fail "Installed fine, but launch failed - open $DEST manually from Applications."

printf '\033[1;32mDone!\033[0m SidePiece is installed. Touch the edge of your screen and Telegram slides out.\n'

# Anonymous install count: fetch a 1-byte file so GitHub counts one download. No IDs, no data sent.
curl -fsSL -o /dev/null --max-time 5 "https://github.com/arbonomous/sidepiece-site/releases/download/beta-1/install-ping.txt" 2>/dev/null || true

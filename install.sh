#!/usr/bin/env bash
set -e

# ─── Configuration ────────────────────────────────────────────────────────────
GITHUB_REPO="hparpia8/artisanal-todoApp"
APP_NAME="TodoApp"
INSTALL_DIR="/Applications"
DMG_NAME="${APP_NAME}.dmg"
RELEASE_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${DMG_NAME}"
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "  ✏  Artisanal Todo — Installer"
echo "  ──────────────────────────────"
echo ""

# Require macOS 14+
OS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if [ "$OS_MAJOR" -lt 14 ]; then
    echo "  ✗ Artisanal Todo requires macOS 14 (Sonoma) or later."
    echo "    Your version: $(sw_vers -productVersion)"
    exit 1
fi

# Check for curl
if ! command -v curl &>/dev/null; then
    echo "  ✗ curl is required but not found."
    exit 1
fi

echo "→ Downloading latest release..."
TMP_DIR=$(mktemp -d)
TMP_DMG="${TMP_DIR}/${DMG_NAME}"

if ! curl -fsSL --progress-bar "${RELEASE_URL}" -o "${TMP_DMG}"; then
    echo ""
    echo "  ✗ Download failed."
    echo "    Make sure a release has been published at:"
    echo "    https://github.com/${GITHUB_REPO}/releases"
    rm -rf "${TMP_DIR}"
    exit 1
fi

echo "→ Mounting disk image..."
MOUNT_OUTPUT=$(hdiutil attach "${TMP_DMG}" -nobrowse 2>&1)
MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | tail -1 | sed 's/.*\(\/Volumes\/.*\)/\1/')

if [ ! -d "${MOUNT_POINT}/${APP_NAME}.app" ]; then
    echo "  ✗ Could not find ${APP_NAME}.app in the disk image."
    hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null || true
    rm -rf "${TMP_DIR}"
    exit 1
fi

echo "→ Installing to ${INSTALL_DIR}..."
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
    echo "  (replacing existing installation)"
    rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi
cp -R "${MOUNT_POINT}/${APP_NAME}.app" "${INSTALL_DIR}/"

echo "→ Cleaning up..."
hdiutil detach "${MOUNT_POINT}" -quiet
rm -rf "${TMP_DIR}"

echo ""
echo "  ✓ Artisanal Todo installed to /Applications"
echo ""
echo "  ℹ  First launch: if macOS blocks the app, go to"
echo "     System Settings → Privacy & Security → click \"Open Anyway\"."
echo ""
echo "  To add the macOS widget:"
echo "    Right-click your desktop → Edit Widgets → search \"Artisanal Todo\""
echo ""

read -rp "  Launch now? [y/N] " reply
echo ""
if [[ $reply =~ ^[Yy]$ ]]; then
    open "${INSTALL_DIR}/${APP_NAME}.app"
fi

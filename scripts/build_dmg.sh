#!/usr/bin/env bash
set -e

# ─── Configuration ────────────────────────────────────────────────────────────
SCHEME="TodoApp"
CONFIGURATION="Release"
ARCHIVE_PATH="build/TodoApp.xcarchive"
EXPORT_PATH="build/export"
DMG_NAME="TodoApp.dmg"
DMG_OUTPUT="build/${DMG_NAME}"
APP_NAME="TodoApp"
VOLUME_NAME="Artisanal Todo"
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "  ✏  Artisanal Todo — Release Build + DMG"
echo "  ─────────────────────────────────────────"
echo ""

# ── 0. Prerequisites ──────────────────────────────────────────────────────────

if ! command -v xcodebuild &>/dev/null; then
    echo "  ✗ xcodebuild not found. Install Xcode from the App Store."
    exit 1
fi

if ! command -v xcodegen &>/dev/null; then
    echo "  ✗ xcodegen not found. Run: make setup"
    exit 1
fi

# ── 1. Generate Xcode project ─────────────────────────────────────────────────

echo "→ Generating Xcode project..."
xcodegen generate --quiet

# ── 2. Archive ────────────────────────────────────────────────────────────────

echo "→ Archiving (Release)..."
rm -rf "${ARCHIVE_PATH}"
xcodebuild \
    -project TodoApp.xcodeproj \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    archive \
    -archivePath "${ARCHIVE_PATH}" \
    | grep -E "^(Build|error:|warning: )" || true

if [ ! -d "${ARCHIVE_PATH}" ]; then
    echo "  ✗ Archive failed — check xcodebuild output above."
    exit 1
fi
echo "  ✓ Archive: ${ARCHIVE_PATH}"

# ── 3. Export .app ────────────────────────────────────────────────────────────

echo "→ Exporting app..."
rm -rf "${EXPORT_PATH}"
mkdir -p "${EXPORT_PATH}"

# Copy app directly from archive (no code-signing export plist needed for ad-hoc)
APP_IN_ARCHIVE="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"
if [ ! -d "${APP_IN_ARCHIVE}" ]; then
    echo "  ✗ Could not find ${APP_NAME}.app in archive."
    exit 1
fi
cp -R "${APP_IN_ARCHIVE}" "${EXPORT_PATH}/"
echo "  ✓ Exported: ${EXPORT_PATH}/${APP_NAME}.app"

# ── 4. Package into DMG ───────────────────────────────────────────────────────

echo "→ Creating DMG..."
rm -f "${DMG_OUTPUT}"

# Use create-dmg if available (prettier), fall back to hdiutil
if command -v create-dmg &>/dev/null; then
    create-dmg \
        --volname "${VOLUME_NAME}" \
        --volicon "${EXPORT_PATH}/${APP_NAME}.app/Contents/Resources/AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 175 190 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 425 190 \
        "${DMG_OUTPUT}" \
        "${EXPORT_PATH}/"
else
    # Fallback: plain hdiutil DMG
    TMP_DMG="build/tmp_rw.dmg"
    hdiutil create \
        -srcfolder "${EXPORT_PATH}" \
        -volname "${VOLUME_NAME}" \
        -fs HFS+ \
        -fsargs "-c c=64,a=16,b=16" \
        -format UDRW \
        -size 120m \
        "${TMP_DMG}"

    hdiutil convert "${TMP_DMG}" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -o "${DMG_OUTPUT}"

    rm -f "${TMP_DMG}"
fi

echo "  ✓ DMG: ${DMG_OUTPUT}"

# ── 5. Notarization (optional — requires paid Apple Developer account) ─────────
#
# To distribute a Gatekeeper-clean build outside the Mac App Store you must:
#
#   a) Enable Hardened Runtime and sign with a Developer ID Application cert:
#        CODE_SIGN_IDENTITY = "Developer ID Application: <Name> (<TeamID>)"
#        ENABLE_HARDENED_RUNTIME = YES
#
#   b) Store your App Store Connect API key (or Apple ID credentials) once:
#        xcrun notarytool store-credentials "notarytool-profile" \
#            --apple-id "you@example.com" \
#            --team-id  "<TeamID>" \
#            --password "<app-specific-password>"
#
#   c) Submit the DMG for notarization and wait for Apple's response:
#        xcrun notarytool submit "${DMG_OUTPUT}" \
#            --keychain-profile "notarytool-profile" \
#            --wait
#
#   d) Staple the notarization ticket to the DMG so it works offline:
#        xcrun stapler staple "${DMG_OUTPUT}"
#
#   e) Verify the result:
#        spctl --assess --type open --context context:primary-signature \
#              --verbose "${DMG_OUTPUT}"
#
# Uncomment the block below once you have a Developer ID cert:
#
# echo "→ Notarizing..."
# xcrun notarytool submit "${DMG_OUTPUT}" \
#     --keychain-profile "notarytool-profile" \
#     --wait
# xcrun stapler staple "${DMG_OUTPUT}"
# echo "  ✓ Notarized and stapled."

# ── 6. Upload to GitHub Releases ──────────────────────────────────────────────
#
# Requires the GitHub CLI (brew install gh) and authentication (gh auth login).
# Replace <tag> with the version tag you want to create, e.g. v1.0.0.
#
# gh release create <tag> "${DMG_OUTPUT}" \
#     --title "Artisanal Todo <tag>" \
#     --notes "Release notes here."
#
# Or upload to an existing draft release:
#   gh release upload <tag> "${DMG_OUTPUT}" --clobber

echo ""
echo "  ✓ Done. Artifacts in build/"
echo "    DMG: ${DMG_OUTPUT}"
echo ""
echo "  Next steps:"
echo "    • Notarize (see comments in this script) — requires paid Developer account"
echo "    • Upload:  gh release create <tag> ${DMG_OUTPUT}"
echo ""

#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

MODE="release"
if [[ "${1:-}" == "--unsigned" ]]; then
    MODE="unsigned"
elif (( $# > 0 )); then
    print -u2 -- "Usage: ${0:t} [--unsigned]"
    exit 64
fi

INFO_PLIST="$ROOT/Packaging/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
APP="$ROOT/.build/distribution/kittenTag.app"
OUTPUT_DIR="$ROOT/.build/releases"
STAGING="$ROOT/.build/dmg-staging"
NOTARY_PROFILE="${NOTARY_PROFILE:-kittenTag-notary}"

mkdir -p "$OUTPUT_DIR"

find_developer_id() {
    security find-identity -v -p codesigning \
        | sed -n 's/^[[:space:]]*[0-9][0-9]*) \([0-9A-F][0-9A-F]*\) "Developer ID Application:.*/\1/p' \
        | head -n 1
}

if [[ "$MODE" == "release" ]]; then
    IDENTITY="${DEVELOPER_ID_APPLICATION:-$(find_developer_id)}"
    if [[ -z "$IDENTITY" ]]; then
        cat >&2 <<EOF
No Developer ID Application certificate with its private key was found.

Create one in Xcode > Settings > Accounts > Manage Certificates,
then run this command again. Do not use an Apple Development,
Mac Distribution, or Developer ID Installer certificate here.
EOF
        exit 1
    fi

    if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        cat >&2 <<EOF
No usable notarization Keychain profile named '$NOTARY_PROFILE' was found.
Run Scripts/configure-notarization.sh once, then retry this release.
EOF
        exit 1
    fi
fi

"$ROOT/Scripts/build-app.sh"

sign_item() {
    local item="$1"
    codesign --force \
        --options runtime \
        --timestamp \
        --sign "$IDENTITY" \
        "$item"
}

if [[ "$MODE" == "release" ]]; then
    # Sign nested code first. Avoid --deep for release signing because it can
    # conceal an incorrectly signed nested component.
    for framework in "$APP"/Contents/Frameworks/*.framework(N); do
        sign_item "$framework"
    done
    sign_item "$APP"

    codesign --verify --deep --strict --verbose=2 "$APP"
    signature_info="$(codesign --display --verbose=4 "$APP" 2>&1)"
    if [[ "$signature_info" != *"runtime"* ]]; then
        print -u2 -- "The kittenTag signature does not include Hardened Runtime."
        exit 1
    fi
    "$ROOT/Scripts/verify-app.sh" "$APP"
fi

rm -rf "$STAGING"
mkdir -p "$STAGING"
/usr/bin/ditto --rsrc --extattr --acl "$APP" "$STAGING/kittenTag.app"
ln -s /Applications "$STAGING/Applications"
if [[ -f "$ROOT/Packaging/DMG/.DS_Store" ]]; then
    cp "$ROOT/Packaging/DMG/.DS_Store" "$STAGING/.DS_Store"
fi

if [[ "$MODE" == "release" ]]; then
    ZIP="$OUTPUT_DIR/kittenTag-$VERSION-$BUILD-notarization.zip"
    DMG="$OUTPUT_DIR/kittenTag-$VERSION.dmg"
    rm -f "$ZIP" "$DMG"

    # Staple the app itself so it remains trusted after being copied out of
    # the disk image and launched later without a network connection.
    /usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"

    rm -rf "$STAGING/kittenTag.app"
    /usr/bin/ditto --rsrc --extattr --acl "$APP" "$STAGING/kittenTag.app"
    hdiutil create -volname kittenTag -srcfolder "$STAGING" -ov -format UDZO "$DMG"
    codesign --force --timestamp --sign "$IDENTITY" "$DMG"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG"
    spctl --assess --type execute --verbose=4 "$APP"

    rm -f "$ZIP"
else
    DMG="$OUTPUT_DIR/kittenTag-$VERSION-UNSIGNED-DO-NOT-DISTRIBUTE.dmg"
    rm -f "$DMG"
    hdiutil create -volname "kittenTag Test Build" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
fi

rm -rf "$STAGING"
(
    cd "$OUTPUT_DIR"
    shasum -a 256 "${DMG:t}" > "${DMG:t}.sha256"
)

print
print -- "$DMG"
print -- "$DMG.sha256"
if [[ "$MODE" == "unsigned" ]]; then
    print -u2 -- "WARNING: This test DMG is ad-hoc signed and must not be distributed."
fi

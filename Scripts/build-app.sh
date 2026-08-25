#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

cd "$ROOT"
# SwiftPM can retain deleted resource files inside an incremental resource
# bundle. Recreate kittenTag's own bundle so removed assets can never leak
# into a release build.
rm -rf \
    "$ROOT/.build/arm64-apple-macosx/release/kittenTag_KittenTag.bundle" \
    "$ROOT/.build/x86_64-apple-macosx/release/kittenTag_KittenTag.bundle"
swift build -c release --product kittenTag --arch arm64
swift build -c release --product kittenTag --arch x86_64

ARM_BIN_DIR="$ROOT/.build/arm64-apple-macosx/release"
INTEL_BIN_DIR="$ROOT/.build/x86_64-apple-macosx/release"
# Keep the unsigned/ad-hoc development bundle in a hidden build directory so
# Spotlight and Launchpad do not present it as a second installed application.
APP="$ROOT/.build/distribution/kittenTag.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"
lipo -create \
    "$ARM_BIN_DIR/kittenTag" \
    "$INTEL_BIN_DIR/kittenTag" \
    -output "$APP/Contents/MacOS/kittenTag"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"
cp -R "$ROOT/Packaging/Fonts" "$APP/Contents/Resources/Fonts"
xcrun actool "$ROOT/Packaging/Assets.xcassets" \
    --compile "$APP/Contents/Resources" \
    --platform macosx \
    --minimum-deployment-target 13.0 \
    --target-device mac \
    --app-icon AppIcon \
    --accent-color AccentColor \
    --output-partial-info-plist "$ROOT/.build/kittenTag-AppIconInfo.plist"

for resource_bundle in "$ARM_BIN_DIR"/*.bundle(N); do
    cp -R "$resource_bundle" "$APP/Contents/Resources/"

    # SwiftUI resolves LocalizedStringKey values from the main app bundle.
    # Keep the SwiftPM bundle for Bundle.module lookups and also expose its
    # localizations at the normal macOS application-bundle location.
    if [[ "${resource_bundle:t}" == "kittenTag_KittenTag.bundle" ]]; then
        for localization in "$resource_bundle"/*.lproj(N); do
            cp -R "$localization" "$APP/Contents/Resources/"
        done
    fi
done

for framework in FLAC ogg opus vorbis; do
    cp -R "$ARM_BIN_DIR/$framework.framework" "$APP/Contents/Frameworks/"
done

# Ship the license texts of every resolved source dependency with the app.
NOTICES_DIR="$APP/Contents/Resources/ThirdPartyNotices"
mkdir -p "$NOTICES_DIR"
cp "$ROOT/LICENSE" "$NOTICES_DIR/kittenTag-MIT.txt"
cp "$ROOT/Packaging/Fonts/OFL.txt" "$NOTICES_DIR/Haskoy-OFL-1.1.txt"
for checkout in "$ROOT/.build/checkouts"/*(/N); do
    license_files=(
        "$checkout"/LICENSE*(N)
        "$checkout"/COPYING*(N)
        "$checkout"/NOTICE*(N)
    )
    (( ${#license_files[@]} == 0 )) && continue

    destination="$NOTICES_DIR/${checkout:t}"
    mkdir -p "$destination"
    cp "${license_files[@]}" "$destination/"
done

install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/kittenTag"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

"$ROOT/Scripts/verify-app.sh" "$APP"

echo "$APP"

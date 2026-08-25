#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="${1:-$ROOT/.build/distribution/kittenTag.app}"
EXECUTABLE="$APP/Contents/MacOS/kittenTag"

fail() {
    print -u2 -- "Release verification failed: $1"
    exit 1
}

[[ -d "$APP" ]] || fail "app bundle not found at $APP"
[[ -x "$EXECUTABLE" ]] || fail "app executable is missing"

architectures="$(lipo -archs "$EXECUTABLE")"
[[ " $architectures " == *" arm64 "* ]] || fail "arm64 executable slice is missing"
[[ " $architectures " == *" x86_64 "* ]] || fail "x86_64 executable slice is missing"

for framework in FLAC ogg opus vorbis; do
    binary="$APP/Contents/Frameworks/$framework.framework/$framework"
    [[ -f "$binary" ]] || fail "$framework framework is missing"
    framework_architectures="$(lipo -archs "$binary")"
    [[ " $framework_architectures " == *" arm64 "* ]] || fail "$framework arm64 slice is missing"
    [[ " $framework_architectures " == *" x86_64 "* ]] || fail "$framework x86_64 slice is missing"
done

if find "$APP" -name 'WelcomeAnimation.html' -print -quit | grep -q .; then
    fail "removed welcome animation leaked into the app bundle"
fi

notices="$APP/Contents/Resources/ThirdPartyNotices"
[[ -d "$notices" ]] || fail "third-party notices are missing"
notice_count="$(find "$notices" -type f | wc -l | tr -d ' ')"
(( notice_count > 0 )) || fail "third-party notices directory is empty"

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
[[ "$bundle_id" == "app.kittentag.kittenTag" ]] || fail "unexpected bundle identifier: $bundle_id"

short_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
build_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
[[ "$short_version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || fail "invalid short version: $short_version"
[[ "$build_version" =~ '^[1-9][0-9]*$' ]] || fail "invalid build version: $build_version"

if /usr/libexec/PlistBuddy -c 'Print :KTBetaExpirationDate' "$APP/Contents/Info.plist" >/dev/null 2>&1; then
    fail "obsolete beta expiration setting is present"
fi

assets="$APP/Contents/Resources/Assets.car"
[[ -f "$assets" ]] || fail "compiled asset catalog is missing"
[[ ! -e "$APP/Contents/Resources/DarkAppIcon.icns" ]] || fail "obsolete standalone dark icon leaked into the bundle"

codesign --verify --deep --strict "$APP"
print -- "Verified kittenTag.app ($architectures, $notice_count third-party notice files)"

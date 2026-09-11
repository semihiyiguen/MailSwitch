#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
mkdir -p "$CLANG_MODULE_CACHE_PATH" dist
SWIFT_BIN="$(xcrun --find swift)"
SWIFTC_BIN="$(xcrun --find swiftc)"
SDK="$(xcrun --show-sdk-path)"
for ARCH in arm64 x86_64; do
    MIN_OS=10.15
    if [ "$ARCH" = arm64 ]; then MIN_OS=11.0; fi
    BUILD="$PWD/.build/direct-$ARCH"
    mkdir -p "$BUILD"
    "$SWIFTC_BIN" -sdk "$SDK" -swift-version 5 -O -target "$ARCH-apple-macosx$MIN_OS" \
        -parse-as-library -emit-module -emit-object -module-name MailSwitchCore \
        Sources/MailSwitchCore/MailClient.swift -emit-module-path "$BUILD/MailSwitchCore.swiftmodule" \
        -o "$BUILD/MailSwitchCore.o"
    "$SWIFTC_BIN" -sdk "$SDK" -swift-version 5 -O -target "$ARCH-apple-macosx$MIN_OS" -parse-as-library \
        -I "$BUILD" Sources/MailSwitch/*.swift "$BUILD/MailSwitchCore.o" \
        -Xlinker -rpath -Xlinker @executable_path/../Frameworks -o "$BUILD/MailSwitch"
done
# A fresh staging directory prevents old build files from entering a release.
STAGE="$(mktemp -d "$PWD/.build/release.XXXXXX")"
trap 'rm -rf -- "$STAGE"' EXIT
APP="$STAGE/MailSwitch.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
lipo -create .build/direct-arm64/MailSwitch .build/direct-x86_64/MailSwitch -output "$APP/Contents/MacOS/MailSwitch"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
cp examples/hello.eml "$APP/Contents/Resources/hello.eml"
"$(dirname "$SWIFT_BIN")/swift-stdlib-tool" --copy --platform macosx \
    --scan-executable "$APP/Contents/MacOS/MailSwitch" \
    --source-libraries "$(dirname "$SWIFT_BIN")/../lib/swift-5.5/macosx" \
    --destination "$APP/Contents/Frameworks"
"$SWIFT_BIN" -sdk "$SDK" scripts/icon.swift "$STAGE/AppIcon.iconset"
iconutil -c icns "$STAGE/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
# Local resources only: strip metadata from this newly generated bundle.
xattr -cr "$APP"
codesign --force --sign "${SIGNING_IDENTITY:--}" "$APP/Contents/Frameworks/libswift_Concurrency.dylib"
codesign --force --sign "${SIGNING_IDENTITY:--}" "$APP"
codesign --verify --deep --strict "$APP"
python3 scripts/privacy_check.py --app "$APP"
ditto -c -k --norsrc --noextattr --noqtn --keepParent "$APP" "$STAGE/MailSwitch.app.zip"
# Only replace generated outputs after a successful build and validation.
if [ -L dist/MailSwitch.app ] || [ -L dist/MailSwitch.app.zip ]; then
    echo 'Refusing to replace symlinked release outputs.' >&2
    exit 1
fi
rm -rf -- dist/MailSwitch.app
mv "$APP" dist/MailSwitch.app
mv "$STAGE/MailSwitch.app.zip" dist/MailSwitch.app.zip
shasum -a 256 dist/MailSwitch.app.zip | sed 's#dist/##' > dist/SHA256SUMS.txt
printf '%s\n' 'Ready: dist/MailSwitch.app and dist/MailSwitch.app.zip'

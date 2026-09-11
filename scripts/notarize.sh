#!/bin/bash
# Requires a locally installed Developer ID Application identity and Keychain profile.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool Keychain profile name}"
case "$SIGNING_IDENTITY" in
    'Developer ID Application: '*) ;;
    *) echo 'A Developer ID Application signing identity is required.' >&2; exit 1 ;;
esac
test -d dist/MailSwitch.app
if [ -L .build ] || [ -L dist ] || [ -L dist/MailSwitch-notarized.app.zip ] || [ -L dist/SHA256SUMS-notarized.txt ]; then
    echo 'Refusing symlinked output paths.' >&2
    exit 1
fi
mkdir -p .build
STAGE="$(mktemp -d "$PWD/.build/notarize.XXXXXX")"
trap 'rm -rf -- "$STAGE"' EXIT
APP="$STAGE/MailSwitch.app"
ditto --norsrc --noextattr --noqtn dist/MailSwitch.app "$APP"
python3 scripts/privacy_check.py --app "$APP"
codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP/Contents/Frameworks/libswift_Concurrency.dylib"
codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
python3 scripts/privacy_check.py --app "$APP"
ditto -c -k --norsrc --noextattr --noqtn --keepParent "$APP" "$STAGE/submission.zip"
xcrun notarytool submit "$STAGE/submission.zip" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$STAGE/result.json"
python3 - "$STAGE/result.json" <<'PY'
import json, sys
with open(sys.argv[1]) as stream:
    result = json.load(stream)
if result.get('status') != 'Accepted':
    sys.exit('Apple did not accept this submission. No distribution ZIP was produced.')
PY
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --norsrc --noextattr --noqtn --keepParent "$APP" "$STAGE/MailSwitch-notarized.app.zip"
mkdir "$STAGE/verify"
ditto -x -k "$STAGE/MailSwitch-notarized.app.zip" "$STAGE/verify"
xcrun stapler validate "$STAGE/verify/MailSwitch.app"
codesign --verify --deep --strict "$STAGE/verify/MailSwitch.app"
spctl --assess --type execute "$STAGE/verify/MailSwitch.app"
mv "$STAGE/MailSwitch-notarized.app.zip" dist/MailSwitch-notarized.app.zip
shasum -a 256 dist/MailSwitch-notarized.app.zip | sed 's#dist/##' > dist/SHA256SUMS-notarized.txt
printf '%s\n' 'Ready: dist/MailSwitch-notarized.app.zip (Apple accepted; ticket stapled and verified).'

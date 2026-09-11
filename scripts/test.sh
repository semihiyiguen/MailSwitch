#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
BUILD="$PWD/.build/checks"
mkdir -p "$BUILD"
SWIFTC_BIN="$(xcrun --find swiftc)"
SDK="$(xcrun --show-sdk-path)"
"$SWIFTC_BIN" -sdk "$SDK" -swift-version 5 -parse-as-library -emit-module -emit-object \
    -module-name MailSwitchCore Sources/MailSwitchCore/MailClient.swift \
    -emit-module-path "$BUILD/MailSwitchCore.swiftmodule" -o "$BUILD/MailSwitchCore.o"
"$SWIFTC_BIN" -sdk "$SDK" -swift-version 5 -parse-as-library -I "$BUILD" \
    scripts/checks.swift Sources/MailSwitch/MacMailSystem.swift "$BUILD/MailSwitchCore.o" -o "$BUILD/checks"
"$BUILD/checks"

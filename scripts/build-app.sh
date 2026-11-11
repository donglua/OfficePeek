#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -d "${ROOT_DIR}/../JZOfficeAndroid" ]]; then
    JZ_OFFICE_ROOT="$(cd "${ROOT_DIR}/../JZOfficeAndroid" && pwd)"
elif [[ -d "${ROOT_DIR}/../JZOfficeViewer" ]]; then
    JZ_OFFICE_ROOT="$(cd "${ROOT_DIR}/../JZOfficeViewer" && pwd)"
else
    echo "::error::JZOfficeAndroid not found at ${ROOT_DIR}/../JZOfficeAndroid or ${ROOT_DIR}/../JZOfficeViewer"
    exit 1
fi
APP_BUNDLE="${ROOT_DIR}/build/OfficePeek.app"
APP_ZIP="${ROOT_DIR}/build/OfficePeek.app.zip"

if [[ ! -d "${JZ_OFFICE_ROOT}/viewer-macos/libs/CJZOffice.xcframework" ]]; then
    echo "==> [0/3] Building CJZOffice.xcframework in JZOfficeAndroid..."
    "${JZ_OFFICE_ROOT}/scripts/build-macos.sh"
fi

echo "==> [1/3] Running OfficePeek unit tests..."
cd "${ROOT_DIR}"
CLT_TESTING_PLUGIN="/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ -f "${CLT_TESTING_PLUGIN}" ]]; then
    swift test --enable-swift-testing --disable-xctest \
        -Xswiftc -load-plugin-library -Xswiftc "${CLT_TESTING_PLUGIN}"
else
    swift test --enable-swift-testing --disable-xctest
fi

echo "==> [2/3] Building OfficePeek release executable..."
swift build -c release

echo "==> [3/3] Packaging macOS application bundle (${APP_BUNDLE})..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"
cp -f "${ROOT_DIR}/.build/release/OfficePeek" "${APP_BUNDLE}/Contents/MacOS/OfficePeek"
cp -f "${ROOT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
if [[ -f "${ROOT_DIR}/Resources/AppIcon.icns" ]]; then
    cp -f "${ROOT_DIR}/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi
printf "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || true
fi

(
    cd "${ROOT_DIR}/build"
    rm -f "${APP_ZIP}"
    zip -qry "OfficePeek.app.zip" "OfficePeek.app"
)

APP_SIZE="$(du -sh "${APP_BUNDLE}" | awk '{print $1}')"
ZIP_SIZE="$(du -sh "${APP_ZIP}" | awk '{print $1}')"
echo "==> Successfully packaged ${APP_BUNDLE} (${APP_SIZE})"
echo "    Archive: ${APP_ZIP} (${ZIP_SIZE})"
echo "    Launch with: open \"${APP_BUNDLE}\""

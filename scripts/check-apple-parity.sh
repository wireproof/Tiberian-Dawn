#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

required_assets='resources/apple/ModernArt/manifest.ini
resources/apple/ModernArt/ui/cursor-default.png
resources/apple/ModernArt/units/buggy/buggy-atlas-4x.png
resources/apple/ModernArt/units/humvee/humvee-atlas-4x.png
resources/apple/ModernArt/units/minigunner/minigunner-atlas-4x-v2.png
resources/apple/ModernArt/units/mcv/gdi-mcv-atlas-4x.png
resources/apple/ModernArt/units/mcv/nod-mcv-atlas-4x.png
resources/apple/ModernArt/units/infrastructure/gdi-infrastructure-atlas-4x.png
resources/apple/ModernArt/units/infrastructure/nod-infrastructure-atlas-4x.png'

printf '%s\n' "$required_assets" | while IFS= read -r asset; do
    test -f "$asset" || { echo "Missing shared Apple asset: $asset" >&2; exit 1; }
    references=$(grep -cF "$asset" tiberiandawn/CMakeLists.txt)
    test "$references" -ge 3 || {
        echo "Shared Apple asset is not packaged by all three native targets: $asset" >&2
        exit 1
    }
done

grep -q 'if(APPLE_NATIVE_PORT)' common/CMakeLists.txt
grep -q 'VISIONOS_PORT' CMakeLists.txt
grep -q '"name": "visionos-simulator"' CMakePresets.json
grep -q '"name": "visionos-device"' CMakePresets.json
grep -q '^  visionos-compile:' .github/workflows/ci.yml
grep -q '#if defined(IPADOS_PORT) || defined(MACOS_PORT)' tiberiandawn/visudlg.cpp
grep -q '#if defined(IPADOS_PORT) || defined(MACOS_PORT)' tiberiandawn/gamedlg.cpp
grep -q '"OPENAL": "OFF"' CMakePresets.json

# Both Apple bundles must derive their public and build versions from the same
# top-level metadata. This prevents a release from showing different versions
# in Finder and iPad Settings even though it was built from one commit.
grep -Eq '^project\(TiberianDawnApple VERSION [0-9]+\.[0-9]+\.[0-9]+ LANGUAGES C CXX\)$' CMakeLists.txt
grep -Eq '^set\(TIBERIAN_DAWN_BUILD_VERSION "[0-9]+"\)$' CMakeLists.txt
grep -q 'MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"' tiberiandawn/CMakeLists.txt
grep -q 'MACOSX_BUNDLE_BUNDLE_VERSION "${TIBERIAN_DAWN_BUILD_VERSION}"' tiberiandawn/CMakeLists.txt
grep -q '<string>${MACOSX_BUNDLE_SHORT_VERSION_STRING}</string>' platform/apple/Info-iPadOS.plist.in
grep -q '<string>@MACOSX_BUNDLE_SHORT_VERSION_STRING@</string>' platform/apple/Info-macOS.plist.in
grep -q '<string>${MACOSX_BUNDLE_SHORT_VERSION_STRING}</string>' platform/apple/Info-visionOS.plist.in
grep -q '<string>${MACOSX_BUNDLE_BUNDLE_VERSION}</string>' platform/apple/Info-visionOS.plist.in
test -f platform/apple/PrivacyInfo.xcprivacy
test -f resources/visionos/Assets.xcassets/Contents.json
test -s patches/SDL2-visionos.patch
grep -q 'patches/SDL2-visionos.patch' scripts/prepare-visionos-dependencies.sh
grep -q 'const CGRect lookScrollFrame = self.bounds' patches/SDL2-visionos.patch
for script in scripts/prepare-visionos-dependencies.sh scripts/configure-visionos.sh \
              scripts/build-visionos-simulator.sh scripts/build-visionos-device.sh; do
    test -x "$script"
    sh -n "$script"
done

if grep -R -n -E 'LegacyRTS|LEGACY_RTS' \
    --exclude=check-apple-parity.sh \
    --exclude-dir=.git --exclude-dir=build --exclude-dir=dist \
    --exclude-dir=third_party .; then
    echo "Obsolete LegacyRTS naming found" >&2
    exit 1
fi

# A blank display name also breaks LiveContainer-generated shortcut labels.
grep -A1 '<key>CFBundleDisplayName</key>' platform/apple/Info-iPadOS.plist.in | grep -q '<string>Tiberian Dawn</string>'
echo "Apple platform parity checks passed."

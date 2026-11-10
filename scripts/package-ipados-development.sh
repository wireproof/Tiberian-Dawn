#!/usr/bin/env bash
set -euo pipefail

# Reuse the complete signed game bundle; a fresh Xcode build contains code but
# does not contain GameData or the Remastered artwork atlases.
if [[ $# -ne 4 ]]; then
    echo "Usage: $0 <full-base.ipa> <new-built.app> <signing-identity> <output.ipa>" >&2
    exit 2
fi

base_ipa=$1
built_app=$2
identity=$3
output_ipa=$4
stage=$(mktemp -d "$(dirname "$output_ipa")/tiberian-ios-package.XXXXXX")
trap 'rm -rf "$stage"' EXIT

unzip -q "$base_ipa" -d "$stage"
app="$stage/Payload/TiberianDawn.app"
for required in GameData ModernArt RemasteredArt embedded.mobileprovision; do
    if [[ ! -e "$app/$required" ]]; then
        echo "Full base IPA is missing $required" >&2
        exit 1
    fi
done
if [[ ! -f "$built_app/TiberianDawn" || ! -f "$built_app/Info.plist" ]]; then
    echo "New build is missing its executable or Info.plist" >&2
    exit 1
fi
if [[ $(plutil -extract CFBundleIdentifier raw "$app/Info.plist") != $(plutil -extract CFBundleIdentifier raw "$built_app/Info.plist") ]]; then
    echo "Bundle identifiers differ" >&2
    exit 1
fi

codesign -d --entitlements :- "$app" > "$stage/entitlements.plist" 2>/dev/null
# Overlay the full built bundle, not only the host executable. Combined builds
# also update a separately loaded Red Alert engine and its private art pack.
# ditto preserves complete base assets when an ordinary source build omits them.
if [[ -f "$built_app/Frameworks/RedAlertEngine.dylib" ]]; then
    for required in RAData/REDALERT.MIX RAData/allied/MAIN.MIX RAData/soviet/MAIN.MIX \
                    RemasteredArtRA/frames.tsv RemasteredArtRA/teams.tsv RemasteredArtRA/manifest.ini; do
        [[ -s "$built_app/$required" ]] || { echo "Combined build is missing $required" >&2; exit 1; }
    done
fi
ditto "$built_app" "$app"
# A source build must not replace the device's existing provisioning profile.
unzip -p "$base_ipa" 'Payload/TiberianDawn.app/embedded.mobileprovision' > "$app/embedded.mobileprovision"
if [[ -d "$app/Frameworks" ]]; then
    while IFS= read -r -d '' library; do
        codesign --force --sign "$identity" --timestamp=none "$library"
    done < <(find "$app/Frameworks" -type f -name '*.dylib' -print0)
fi
codesign --force --sign "$identity" --entitlements "$stage/entitlements.plist" --timestamp=none "$app"
codesign --verify --deep --strict "$app"

partial="$output_ipa.partial"
rm -f "$partial"
(cd "$stage" && zip -qry -0 "$partial" Payload)
unzip -tq "$partial"
python3 - "$partial" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    names = set(archive.namelist())
    for folder in ("GameData", "ModernArt", "RemasteredArt"):
        prefix = f"Payload/TiberianDawn.app/{folder}/"
        if not any(name.startswith(prefix) and not name.endswith("/") for name in names):
            raise SystemExit(f"Packaged IPA is missing {folder} files")
    engine = "Payload/TiberianDawn.app/Frameworks/RedAlertEngine.dylib"
    if engine in names:
        for required in ("RAData/REDALERT.MIX", "RAData/allied/MAIN.MIX", "RAData/soviet/MAIN.MIX",
                         "RemasteredArtRA/frames.tsv", "RemasteredArtRA/teams.tsv", "RemasteredArtRA/manifest.ini"):
            path = "Payload/TiberianDawn.app/" + required
            if path not in names or not archive.getinfo(path).file_size:
                raise SystemExit(f"Packaged combined IPA is missing {required}")
PY
mv -f "$partial" "$output_ipa"
shasum -a 256 "$output_ipa"

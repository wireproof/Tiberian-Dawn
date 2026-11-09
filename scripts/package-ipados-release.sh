#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <full-unsigned-base.ipa> <new-built.app> <output.ipa>" >&2
    exit 2
fi

base_ipa=$1
built_app=$2
output_ipa=$3
stage=$(mktemp -d "$(dirname "$output_ipa")/tiberian-release.XXXXXX")
trap 'rm -rf "$stage"' EXIT

unzip -q "$base_ipa" -d "$stage"
app="$stage/Payload/TiberianDawn.app"
for required in GameData ModernArt RemasteredArt; do
    [[ -d "$app/$required" ]] || { echo "Missing $required" >&2; exit 1; }
done
[[ -f "$built_app/TiberianDawn" && -f "$built_app/Info.plist" ]] || {
    echo "New build is missing its executable or Info.plist" >&2; exit 1;
}
[[ $(plutil -extract CFBundleIdentifier raw "$app/Info.plist") == \
   $(plutil -extract CFBundleIdentifier raw "$built_app/Info.plist") ]] || {
    echo "Bundle identifiers differ" >&2; exit 1;
}

cp "$built_app/TiberianDawn" "$app/TiberianDawn"
cp "$built_app/Info.plist" "$app/Info.plist"
rm -rf "$app/_CodeSignature" "$app/embedded.mobileprovision"

partial="$output_ipa.partial"
rm -f "$partial"
(cd "$stage" && zip -qry -6 "$partial" Payload)
unzip -tq "$partial"
python3 - "$partial" <<'PY'
import plistlib
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    names = archive.namelist()
    prefix = 'Payload/TiberianDawn.app/'
    for folder in ('GameData', 'ModernArt', 'RemasteredArt'):
        if not any(name.startswith(prefix + folder + '/') and not name.endswith('/') for name in names):
            raise SystemExit(f'Missing {folder} content')
    if any('_CodeSignature/' in name or name.endswith('embedded.mobileprovision') for name in names):
        raise SystemExit('Signing material found in unsigned release')
    info = plistlib.loads(archive.read(prefix + 'Info.plist'))
    print('Release IPA:', info['CFBundleShortVersionString'], info['CFBundleVersion'], len(names), 'entries')
PY
mv -f "$partial" "$output_ipa"
shasum -a 256 "$output_ipa"

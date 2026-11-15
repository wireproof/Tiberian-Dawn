#!/usr/bin/env bash
set -euo pipefail

# Preserve the completed combined-game payload while moving it to a newly
# provisioned app identity. The signed skeleton supplies only its provisioning
# profile and entitlements; its single-game executable is never copied.
if [[ $# -ne 4 ]]; then
    echo "Usage: $0 <full-build721.ipa> <signed-new-id.app> <signing-identity> <output.ipa>" >&2
    exit 2
fi

base_ipa=$1
signed_app=$2
identity=$3
output_ipa=$4
stage=$(mktemp -d "$(dirname "$output_ipa")/cnc-bundle-migration.XXXXXX")
trap 'rm -rf "$stage"' EXIT

unzip -q "$base_ipa" -d "$stage"
app="$stage/Payload/TiberianDawn.app"
plist="$app/Info.plist"
old_id=$(plutil -extract CFBundleIdentifier raw "$plist")
new_id=$(plutil -extract CFBundleIdentifier raw "$signed_app/Info.plist")
[[ "$old_id" == com.wireproof.tiberiandawn ]] || { echo "Unexpected source bundle ID: $old_id" >&2; exit 1; }
[[ "$new_id" == com.wireproof.cnc ]] || { echo "Unexpected new bundle ID: $new_id" >&2; exit 1; }
[[ $(plutil -extract CFBundleVersion raw "$plist") == 721 ]] || { echo 'Source IPA is not build 721' >&2; exit 1; }
[[ $(plutil -extract CFBundleVersion raw "$signed_app/Info.plist") == 722 ]] || { echo 'Signed app is not build 722' >&2; exit 1; }
for required in GameData ModernArt RemasteredArt RAData RemasteredArtRA Frameworks/RedAlertEngine.dylib selector-reference.png; do
    [[ -e "$app/$required" ]] || { echo "Combined payload is missing $required" >&2; exit 1; }
done
[[ -s "$signed_app/embedded.mobileprovision" ]] || { echo 'New provisioning profile is missing' >&2; exit 1; }

plutil -replace CFBundleIdentifier -string "$new_id" "$plist"
plutil -replace CFBundleVersion -string '722' "$plist"
cp "$signed_app/embedded.mobileprovision" "$app/embedded.mobileprovision"
codesign -d --entitlements :- "$signed_app" > "$stage/new-entitlements.plist" 2>/dev/null
while IFS= read -r -d '' library; do
    codesign --force --sign "$identity" --timestamp=none "$library"
done < <(find "$app/Frameworks" -type f -name '*.dylib' -print0)
codesign --force --sign "$identity" --entitlements "$stage/new-entitlements.plist" --timestamp=none "$app"
codesign --verify --deep --strict "$app"
[[ $(plutil -extract CFBundleIdentifier raw "$plist") == "$new_id" ]]

partial="$output_ipa.partial"
rm -f "$partial"
(cd "$stage" && zip -qry -0 "$partial" Payload)
unzip -tq "$partial"
mv "$partial" "$output_ipa"
shasum -a 256 "$output_ipa"

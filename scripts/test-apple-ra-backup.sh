#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
binary="$(mktemp -t ra-backup-test)"
trap 'rm -f "$binary"' EXIT
xcrun clang++ -std=c++14 -fobjc-arc -I . -I common tests/apple_ra_backup.mm common/savegame_transfer.cpp common/sha.cpp -framework Foundation -framework AppKit -framework UniformTypeIdentifiers -o "$binary"
"$binary"

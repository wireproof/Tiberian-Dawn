#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
binary="$(mktemp -t td-backup-test)"
trap 'rm -f "$binary"' EXIT
xcrun clang++ -std=c++14 -fobjc-arc -I . tests/apple_backup.mm common/savegame_transfer.cpp -framework Foundation -framework AppKit -framework UniformTypeIdentifiers -o "$binary"
"$binary"

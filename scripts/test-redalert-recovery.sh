#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
binary="$(mktemp -t ra-recovery-test)"
trap 'rm -f "$binary"' EXIT
xcrun clang++ -std=c++14 -I . -I common tests/redalert_recovery.cpp common/recovery_transaction.cpp common/sha.cpp -o "$binary"
"$binary"

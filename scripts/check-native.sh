#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
native_test_dir=$(mktemp -d "${TMPDIR:-/tmp}/penguin-native.XXXXXX")
trap 'rm -rf "$native_test_dir"' EXIT
node scripts/native-fixtures.cjs "$native_test_dir/fixtures.json"
xcrun swiftc -module-cache-path "$native_test_dir/modules" PenguinPush/Sokoban.swift PenguinPush/GameStore.swift PenguinPush/LegacySaveMigration.swift scripts/native-tests.swift -o "$native_test_dir/native-tests"
"$native_test_dir/native-tests" "$native_test_dir/fixtures.json"

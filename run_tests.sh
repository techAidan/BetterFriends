#!/bin/bash
# Run all BetterFriends addon tests
# Uses Lua 5.1 to match WoW's Lua environment

LUA="/c/Users/BlackHole/.vscode/extensions/actboy168.lua-debug-2.2.2-win32-x64/runtime/win32-x64/lua51/lua.exe"

if [ ! -f "$LUA" ]; then
    echo "ERROR: Lua 5.1 not found at $LUA"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

all_passed=true

# Run each test file
for test_file in tests/test_*.lua; do
    # Skip the test_runner.lua itself
    if [ "$(basename "$test_file")" = "test_runner.lua" ]; then
        continue
    fi

    echo "========================================"
    echo "Running: $test_file"
    echo "========================================"

    "$LUA" "$test_file"
    if [ $? -ne 0 ]; then
        all_passed=false
    fi
done

echo ""
if [ "$all_passed" = true ]; then
    echo "ALL TEST SUITES PASSED"
    exit 0
else
    echo "SOME TEST SUITES FAILED"
    exit 1
fi

#!/bin/bash
set -E

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR

warn "$0"

# Run the script
inputPath=source/index.html
outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
"../../engine.sh" -c "$cacheDir" -r "." "$inputPath" > "$outputPath"

# Common assertions
assert_cache_ok "$cacheDir"

# Test assertions
count=$(grep -c '<meta charset' "$outputPath")
assert "output has charset" "$count == 1"

count=$(grep -c '<title' "$outputPath")
assert "output has title" "$count == 1"
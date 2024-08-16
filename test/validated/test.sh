#!/bin/bash
set -E

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR


# Run the script
inputPath=source/index.html
outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
"../../engine.sh" -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath"

# Common assertions
assert_cache_ok "$cacheDir"

# Test assertions

# we use grep -c with || true, because grep returns an error on no matches, and that can be correct
count=$(grep -c '<meta charset' "$outputPath" || true)
assert "output should not have charset" "$count == 0"

count=$(grep -c '<h1' "$outputPath" || true)
assert "output has h1" "$count == 1"

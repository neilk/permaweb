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
export PERMAWEB_FAILING_SCRIPT_SEMAPHORE=$(mktemp -q /tmp/permaweb.XXXXX || exit 1)
"../../permaweb" -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath"

# Common assertions
assert_cache_ok "$cacheDir"

# Test assertions
count=$(grep -c '<meta charset' "$outputPath")
assert "output has charset" "$count == 1"

assert "failing script ran and had no effect" "-e $PERMAWEB_FAILING_SCRIPT_SEMAPHORE"
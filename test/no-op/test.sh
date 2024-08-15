#!/bin/bash
set -E
trap 'handle_error $LINENO' ERR

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

source "$(dirname "$testDir")/lib.sh"


# Run the script
inputPath=source/index.html
outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
cacheDir=$(mktemp -q -d "/tmp/permaweb.XXXXX" || exit 1)
"../../engine.sh" -c "$cacheDir" -r "." "$inputPath" > "$outputPath"

# Common assertions
assert_cache_ok "$cacheDir"


# Test assertions

# Because it was a no-op, the original should hash the same as the output
inputHash=$(getFileHash "$inputPath")
outputHash=$(getFileHash "$outputPath")
assert "output is same as input" "$inputHash == $outputHash"



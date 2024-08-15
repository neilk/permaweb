#!/bin/bash
set -e 
testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit
rm -rf ".engine"

source "$(dirname "$testDir")/lib.sh"

# Run the script
inputPath=source/index.html
outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
"../../engine.sh" -r "." "$inputPath" > "$outputPath"


warn "$0"

# Common assertions
assert_engine_dir_structure_ok "$testDir"


# Assertions particular to this test

# Because it was a no-op, the original should hash the same as the output
inputHash=$(getFileHash "$inputPath")
outputHash=$(getFileHash "$outputPath")
assert "output is same as input" "$inputHash == $outputHash"



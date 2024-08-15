#!/bin/bash
set -E

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit
rm -rf ".engine"

source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR

# Run the script
inputPath=source/index.html
outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
"../../engine.sh" -r "." "$inputPath" > "$outputPath"


warn "$0"

# Common assertions
assert_engine_dir_structure_ok "$testDir"


# Assertions particular to this test
count=$(grep -c '<meta charset' "$outputPath")
assert "output is modified" "$count == 1"

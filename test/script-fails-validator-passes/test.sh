#!/bin/bash
set -E
testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit
source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR

inputPath=source/index.html
outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
"../../single.sh" -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath" 2>/dev/null

assert_cache_ok "$cacheDir"

# A script that exits non-zero is a failure even if its stdout validates.
count=$(grep -c 'SHOULD-NOT-APPEAR' "$outputPath" || true)
assert "output from the failing script is discarded" "$count == 0"
count=$(grep -c 'ORIGINAL' "$outputPath" || true)
assert "original content is passed through" "$count == 1"

scriptHash=$(sha1sum scripts/html/10_fail_with_valid_output.sh | cut -d' ' -f1)
inputHash=$(sha1sum "$inputPath" | cut -d' ' -f1)
cachedExit=$(cat "$cacheDir/exec/$inputHash/$scriptHash/exit")
assert "cached exit code records the script failure" "$cachedExit != 0"

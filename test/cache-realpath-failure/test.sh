#!/bin/bash
set -E
testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit
source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR

inputPath=source/index.html
outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)

export PERMAWEB_TEST_REAL_REALPATH
PERMAWEB_TEST_REAL_REALPATH=$(command -v realpath)

# Run with a realpath that cannot compute relative paths.
PATH="$testDir/fakebin:$PATH" "../../single.sh" -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath" 2>/dev/null || true

# Whatever happened, no cache entry may claim success while pointing at nothing.
poisoned=0
for exitFile in "$cacheDir"/exec/*/*/exit; do
    [ -f "$exitFile" ] || continue
    if [[ "$(cat "$exitFile")" == "0" && ! -e "$(dirname "$exitFile")/1" ]]; then
        poisoned=$((poisoned + 1))
    fi
done
assert "no cache entry records success with a dangling stdout link" "$poisoned == 0"

# With a working realpath, the next build must transform the page.
"../../single.sh" -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath" 2>/dev/null
count=$(grep -c 'ADDED' "$outputPath" || true)
assert "a later run with a working realpath transforms the page" "$count == 1"
assert_cache_ok "$cacheDir"

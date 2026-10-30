#!/bin/bash
set -E
testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit
source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR

inputPath=source/index.html
outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
scriptHash=$(sha1sum scripts/html/10_add_marker.sh | cut -d' ' -f1)
inputHash=$(sha1sum "$inputPath" | cut -d' ' -f1)
entry="$cacheDir/exec/$inputHash/$scriptHash"

"../../single.sh" -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath" 2>/dev/null
count=$(grep -c 'ADDED' "$outputPath" || true)
assert "first run transforms the page" "$count == 1"
assert "cache entry exists" "-f $entry/exit"

# Corrupt the cache the way a failed realpath did: exit says 0, stdout link points nowhere.
ln -sf "" "$entry/1"
assert "stdout link is now dangling" "! -e $entry/1"

"../../single.sh" -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath" 2>/dev/null
count=$(grep -c 'ADDED' "$outputPath" || true)
assert "second run still transforms the page despite the corrupt cache entry" "$count == 1"
assert "cache entry has been repaired" "-e $entry/1"
assert_cache_ok "$cacheDir"

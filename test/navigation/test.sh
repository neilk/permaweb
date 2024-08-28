#!/bin/bash
set -E

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR



# We'll test one file, to start
for inputPath in source/*.html; do
    outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
    cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
    "../../permaweb" -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath"

    # Common assertions
    assert_cache_ok "$cacheDir"

    # Test that navigation has all siblings and self
    for siblingPath in source/*.html; do
        count=$(grep -c "$(basename "$siblingPath")" "$outputPath")
        assert "navigation in $inputPath has ${siblingPath}" "$count == 1"
    done

    # Test that in the navigation, self is special
    selfBoldCount=$(grep -c "<strong><a href=\"$(basename "$inputPath")\"" "$outputPath")
    assert "navigation in $inputPath has self bolded" "$selfBoldCount == 1"
    boldCount=$(grep -c "<strong>" "$outputPath")
    assert "navigation in $inputPath has only one bolded" "$boldCount == 1"
    
done
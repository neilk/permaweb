#!/bin/bash
set -E

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR

# Test for directory-based scripts with dependent files
# The structure is:
# - scripts/html/10_addHeader/main.sh (executable entry point)
# - scripts/html/10_addHeader/header.html (dependent data file)

# Run the initial test
inputPath=source/index.html
outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
../../permaweb -d -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath"

# Common assertions
assert_cache_ok "$cacheDir"

# Test assertions
headerCount=$(grep -c 'Directory-Based Script Test' "$outputPath")
assert "header was added from the dependent file" "$headerCount == 1"

# Store the object hash of the script's output for comparison later
firstRunObj=$(find "$cacheDir/exec" -name "1" -print0 | xargs -0 readlink)

# Modify the header.html file to test invalidation
sed -i.bak 's/Directory-Based Script Test/MODIFIED Header Test/g' scripts/html/10_addHeader/header.html

# Run again - should use new header
outputPath2=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
../../permaweb -d -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath2"

# Verify the header was updated (cache was invalidated)
modifiedCount=$(grep -c 'MODIFIED Header Test' "$outputPath2")
assert "header was updated after dependent file change" "$modifiedCount == 1"

# Get the new object hash to confirm it changed
secondRunObj=$(find "$cacheDir/exec" -name "1" -print0 | xargs -0 readlink)
assert "cache object changed when dependent file changed" "$firstRunObj != $secondRunObj"

# Cleanup
rm -f "$outputPath" "$outputPath2" scripts/html/10_addHeader/header.html.bak

warn "All tests passed!"
exit 0
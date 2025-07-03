#!/bin/bash
set -E

# Test for map-reduce script invalidation
# This test verifies that when scripts change, the cache is properly invalidated
# and only the changed scripts (and their dependents) re-run.

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

# shellcheck disable=SC1091
source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR

# Create temporary directories for cache and output
cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
outputDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)

# where we expect output to be generated
outputFile="$outputDir/linecount.txt"

# Run the map-reduce process with specified reducers directory
doMapReduce() {
    local reducersDir="$1"
    ../../reduce.sh -c "$cacheDir" -s "$reducersDir" -o "$outputDir" "source"
}

# ========
# First run with reducers_1
# ========

PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD

doMapReduce "./reducers_1"

# Common assertions for cache integrity
assert_cache_ok "$cacheDir"

# Verify output file was created
assert "output file was created at $outputFile" "-f $outputFile"

# Check that the count matches expected value (3 + 2 = 5 lines total)
actual_output1=$(< "$outputFile")
expected_output1="5"
assert "first run output matches expected value" "$actual_output1 == $expected_output1"

# Verify that map scripts ran on all source files, and then one reduce script
expectedScriptRecord1=$(cat << 'EOF'
map.sh
map.sh
reduce.sh
EOF
)
scriptRecordMatch1=false
if diff <(echo "$expectedScriptRecord1") "$PERMAWEB_SCRIPT_RECORD" > /dev/null; then
    scriptRecordMatch1=true
fi
assert "first run: map and reduce scripts ran as expected" "$scriptRecordMatch1 == true"

# ========
# Second run with same reducers_1 - should use cache
# ========

PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD

doMapReduce "./reducers_1"

# Scripts should not have run if cache is working
isScriptRecordEmpty=1
if [ ! -s "$PERMAWEB_SCRIPT_RECORD" ]; then
    isScriptRecordEmpty=0
fi
assert "second run with same scripts: no scripts ran, cache was used" $isScriptRecordEmpty

# Output should be the same
actual_output2=$(< "$outputFile")
assert "second run output still matches expected value" "$actual_output2 == $expected_output1"

# ========
# Third run with reducers_2 - reduce script changed, map script unchanged
# ========

PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD

doMapReduce "./reducers_2"

# Only reduce script should run because map script hash is the same but reduce script hash changed
expectedScriptRecord3=$(cat << 'EOF'
reduce.sh
EOF
)
scriptRecordMatch3=false
if diff <(echo "$expectedScriptRecord3") "$PERMAWEB_SCRIPT_RECORD" > /dev/null; then
    scriptRecordMatch3=true
fi
assert "third run with changed reduce script: only reduce script ran" "$scriptRecordMatch3 == true"

# Output should be different due to changed reduce script (adds "Total: " prefix)
actual_output3=$(< "$outputFile")
expected_output3="Total: 5"
assert "third run output reflects script change" "\"${actual_output3}\"==\"${expected_output3}\""

# ========
# Fourth run with same reducers_2 - should use cache again
# ========

PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD

doMapReduce "./reducers_2"

# Scripts should not have run if cache is working
isScriptRecordEmpty=1
if [ ! -s "$PERMAWEB_SCRIPT_RECORD" ]; then
    isScriptRecordEmpty=0
fi
assert "fourth run with same changed scripts: no scripts ran, cache was used" $isScriptRecordEmpty

# Output should be the same as third run
actual_output4=$(< "$outputFile")
assert "fourth run output unchanged from third run"  "\"${actual_output4}\"==\"${expected_output3}\""

# Clean up after testing
# rm -rf "$cacheDir"
# rm -rf "$outputDir"
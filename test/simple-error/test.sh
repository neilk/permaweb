#!/bin/bash
set -E

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR


# Run the script
inputPath=source/index.html
outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
errorPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
scriptHash=$(sha1sum "scripts/html/10_always_error.sh" | cut -d' ' -f1)
inputHash=$(sha1sum "$inputPath" | cut -d' ' -f1)
expectedCachedErrorPath="$cacheDir/exec/$inputHash/$scriptHash/2"

# get a random number to look for in test output
PERMAWEB_TEST_ERROR_NUMBER=$(shuf -i 1-10000 -n 1)
# also save it for later; see below
ORIGINAL_PERMAWEB_TEST_ERROR_NUMBER=$PERMAWEB_TEST_ERROR_NUMBER
export PERMAWEB_TEST_ERROR_NUMBER

"../../single.sh" -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath" 2> "$errorPath"

# Common assertions
assert_cache_ok "$cacheDir"

# Test assertions
# The stderr of permaweb's execution should have printed the error
errorInStderrCount=$(grep -c "${PERMAWEB_TEST_ERROR_NUMBER}" "$errorPath")
assert "error is in stderr" "$errorInStderrCount == 1"

# The error should also have been saved in the cache

assert "error file is in cache at expected location" "-f $expectedCachedErrorPath"
errorInCacheCount=$(grep -c "${PERMAWEB_TEST_ERROR_NUMBER}" "$expectedCachedErrorPath")
assert "expected error is in cache" "$errorInCacheCount == 1"

# Running the script again should give the exact same results with the same error number as before,
# because it is cached. There is no reason to run the failing script again on the same content, 
# so the cached error is displayed. (permaweb assumes that the script is deterministic, and does not 
# depend upon the environment or any other state not explicitly passed)
# Here we change the error number passed in the environment. We expect this to NOT appear in output.
PERMAWEB_TEST_ERROR_NUMBER=$(shuf -i 1-10000 -n 1)
export PERMAWEB_TEST_ERROR_NUMBER
assert "error number has changed for re-run" "[$PERMAWEB_TEST_ERROR_NUMBER != $ORIGINAL_PERMAWEB_TEST_ERROR_NUMBER]"

"../../single.sh" -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath" 2> "$errorPath"
errorInStderrCount2=$(grep -c "${ORIGINAL_PERMAWEB_TEST_ERROR_NUMBER}" "$errorPath")
assert "even after re-run, original error was shown in stderr" "$errorInStderrCount2 == 1"

errorInCacheCount=$(grep -c "${ORIGINAL_PERMAWEB_TEST_ERROR_NUMBER}" "$expectedCachedErrorPath")
assert "even after re-run, original error is still in cache" "$errorInCacheCount == 1"

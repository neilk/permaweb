#!/bin/bash
set -E

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

# shellcheck disable=SC1091
source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR

# Setup function to generate a file with N lines, with unique content
generate_file() {
    local file_path=$1
    local num_lines=$2
    
    rm -f "$file_path" 2>/dev/null

    # Create the directory if it doesn't exist
    mkdir -p "$(dirname "$file_path")"
    
    # Generate the file with specified number of lines
    for i in $(seq 1 "$num_lines"); do
        # 8 random alphanumeric characters
        randomText=$(LC_CTYPE=C tr -dc '[:alnum:]' < /dev/random | head -c 8)
        echo "Line $i - $randomText" >> "$file_path"
    done
}

# Generate test files with different line counts
generate_file "source/file1.txt" 5
generate_file "source/file2.txt" 10
generate_file "source/file3.txt" 15

# Expected total line count
expected_count=$((5 + 10 + 15))

# Run the map-reduce script
targetFile="linecount.txt"
cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
outputDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)

# We'll watch these files to see if the map and reduce scripts ran
PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD

# Run the map-reduce process
../../permaweb-mr.sh -d -c "$cacheDir" -s "./scripts" -o "$outputDir" "source" "$targetFile"

# Common assertions for cache integrity
assert_cache_ok "$cacheDir"

# Verify output file was created
assert "output file was created" "-f $outputDir/$targetFile"

# Check that the count matches expected value
actual_count=$(< "$outputDir/$targetFile")
assert "line count matches expected value" "$actual_count == $expected_count"

# Verify that map scripts ran on all source files, and then one reduce script
# TODO : validate the final results? An RSS validator or something
expectedScriptRecord1=$(cat << 'EOF'
map.sh
map.sh
map.sh
reduce.sh
EOF
)
scriptRecordMatch1=false
if diff <(echo "$expectedScriptRecord1") "$PERMAWEB_SCRIPT_RECORD" > /dev/null; then
    scriptRecordMatch1=true
fi
assert "map and reduce scripts ran" "$scriptRecordMatch1 == true"

# Run the script again to test caching
PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD

../../permaweb-mr.sh -c "$cacheDir" -s "./scripts" -o "$outputDir" "source" "$targetFile"

# Scripts should not have run if cache is working
isScriptRecordEmpty=1
if [ ! -s "$PERMAWEB_SCRIPT_RECORD" ]; then
    isScriptRecordEmpty=0
fi
assert "On second run, no map or reduce ran; cache was used" $isScriptRecordEmpty

# Check that the count still matches expected value
actual_count=$(< "$outputDir/$targetFile")
assert "line count still matches expected value" "$actual_count == $expected_count"

# Now modify one of the source files to test cache invalidation
generate_file "source/file2.txt" 12  # Changed from 10 to 12 lines

# Update expected count
expected_count=$((5 + 12 + 15))

../../permaweb-mr.sh -c "$cacheDir" -s "./scripts" -o "$outputDir" "source" "$targetFile"

# Verify that map scripts ran on the changed file only, and then one reduce script
expectedScriptRecord1=$(cat << 'EOF'
map.sh
reduce.sh
EOF
)

# Check that the updated count matches expected value
actual_count=$(< "$outputDir/$targetFile")
assert "updated line count matches expected value" "$actual_count == $expected_count"

# Clean up after testing
#rm -rf "$cacheDir"
#rm -rf "$outputDir"

echo "All tests passed!"
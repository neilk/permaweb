#!/bin/bash
set -E

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR

# Setup function to generate a file with N lines, each with some entropy
generate_file() {
    local file_path=$1
    local num_lines=$2
    
    # Create the directory if it doesn't exist
    mkdir -p "$(dirname "$file_path")"
    
    # Generate the file with specified number of lines
    for i in $(seq 1 "$num_lines"); do
        # Add some entropy from /dev/urandom (using only printable chars)
        entropy=$(LC_CTYPE=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 8)
        echo "Line $i - $entropy" >> "$file_path"
    done
}

# Setup test environment
rm -rf source
mkdir -p source

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

# Configure test environment variables
PERMAWEB_MAP_RUN_COUNT=0
export PERMAWEB_MAP_RUN_COUNT
PERMAWEB_REDUCE_RUN_COUNT=0
export PERMAWEB_REDUCE_RUN_COUNT

# Run the map-reduce process
../../permaweb-mr.sh -d -c "$cacheDir" -s "./scripts" -o "$outputDir" "source" "$targetFile"

# Common assertions for cache integrity
assert_cache_ok "$cacheDir"

# Verify additional cache directories were created
assert "map cache directory exists" "-d $cacheDir/map"
assert "reduce cache directory exists" "-d $cacheDir/reduce"

# Verify output file was created
assert "output file was created" "-f $outputDir/$targetFile"

# Check that the count matches expected value
actual_count=$(cat "$outputDir/$targetFile")
assert "line count matches expected value" "$actual_count == $expected_count"

# Verify that all map scripts ran
assert "Map scripts ran for all files" "$PERMAWEB_MAP_RUN_COUNT == 3"
assert "Reduce script ran once" "$PERMAWEB_REDUCE_RUN_COUNT == 1"

# Run the script again to test caching
# Should detect that nothing has changed and use cached values
PERMAWEB_MAP_RUN_COUNT=0
export PERMAWEB_MAP_RUN_COUNT
PERMAWEB_REDUCE_RUN_COUNT=0
export PERMAWEB_REDUCE_RUN_COUNT

../../permaweb-mr.sh -c "$cacheDir" -s "./scripts" -o "$outputDir" "source" "$targetFile"

# Scripts should not have run if cache is working
assert "Map script was not run (cache working)" "$PERMAWEB_MAP_RUN_COUNT == 0"
assert "Reduce script was not run (cache working)" "$PERMAWEB_REDUCE_RUN_COUNT == 0"

# Now modify one of the source files to test cache invalidation
generate_file "source/file2.txt" 12  # Changed from 10 to 12 lines

# Reset counters
PERMAWEB_MAP_RUN_COUNT=0
export PERMAWEB_MAP_RUN_COUNT
PERMAWEB_REDUCE_RUN_COUNT=0
export PERMAWEB_REDUCE_RUN_COUNT

# Update expected count
expected_count=$((5 + 12 + 15))

../../permaweb-mr.sh -c "$cacheDir" -s "./scripts" -o "$outputDir" "source" "$targetFile"

# Only one map script should have run (for the modified file)
assert "Map script ran once for modified file" "$PERMAWEB_MAP_RUN_COUNT == 1"
# Reduce should have run because its input changed
assert "Reduce script ran because input changed" "$PERMAWEB_REDUCE_RUN_COUNT == 1"

# Check that the updated count matches expected value
actual_count=$(cat "$outputDir/$targetFile")
assert "updated line count matches expected value" "$actual_count == $expected_count"

# Clean up after testing
rm -rf "$cacheDir"
rm -rf "$outputDir"
rm -rf "source"

echo "All tests passed!"
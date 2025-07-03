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

getExpectedFileContents() {
    local numLines=$1
    echo "This is the linecount: $numLines"
}


cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
outputDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)

# where we expect output to be generated
outputFile="$outputDir/linecount.txt"

# Run the map-reduce process
doMapReduce() {
    ../../reduce.sh -c "$cacheDir" -s "./reducers" -o "$outputDir" "source"
}

# We'll watch these files to see if the map and reduce scripts ran
PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD

# This helps the scripts understand their own context
PERMAWEB_SCRIPT_RECORD_BASE=$testDir
export PERMAWEB_SCRIPT_RECORD_BASE

doMapReduce

# Common assertions for cache integrity
assert_cache_ok "$cacheDir"

# Verify output file was create
assert "output file was created at $outputFile" "-f $outputFile"

# Check that the count matches expected value
actual_file_contents=$(< "$outputFile")
expected_file_contents=$(getExpectedFileContents "$expected_count")

assert "file contents matches expected value" "\"${actual_file_contents}\"==\"${expected_file_contents}\""

# Verify that map scripts ran on all source files, and then one reduce script
# TODO : validate the final results? An RSS validator or something
expectedScriptRecord1=$(cat << 'EOF'
reducers/txt/linecount.txt/map/main.sh
reducers/txt/linecount.txt/map/main.sh
reducers/txt/linecount.txt/map/main.sh
reducers/txt/linecount.txt/reduce/main.sh
EOF
)
scriptRecordMatch1=false
if diff <(echo "$expectedScriptRecord1") "$PERMAWEB_SCRIPT_RECORD" > /dev/null; then
    scriptRecordMatch1=true
fi

assert "map and reduce scripts ran as expected" "$scriptRecordMatch1 == true"

# Run the script again to test caching
PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD

doMapReduce

# Scripts should not have run if cache is working
isScriptRecordEmpty=1
if [ ! -s "$PERMAWEB_SCRIPT_RECORD" ]; then
    isScriptRecordEmpty=0
fi
assert "On second run, no map or reduce ran; cache was used" $isScriptRecordEmpty

# Check that the count still matches expected value
actual_file_contents=$(< "$outputFile")
expected_file_contents=$(getExpectedFileContents "$expected_count")
assert "file contents still matches expected value" "\"${actual_file_contents}\"==\"${expected_file_contents}\""

# Now modify one of the source files to test cache invalidation
generate_file "source/file2.txt" 12  # Changed from 10 to 12 lines

# Update expected count
expected_count=$((5 + 12 + 15))

doMapReduce

# Verify that map scripts ran on the changed file only, and then one reduce script
expectedScriptRecord3=$(cat << 'EOF'
reducers/txt/linecount.txt/map/main.sh
reducers/txt/linecount.txt/reduce/main.sh
EOF
)
scriptRecordMatch3=false
if diff <(echo "$expectedScriptRecord3") "$PERMAWEB_SCRIPT_RECORD" > /dev/null; then
    scriptRecordMatch3=true
fi
assert "On third run, only updated file was re-mapped, then all reduced" "$scriptRecordMatch3 == true"


# Check that the updated count matches expected value
actual_file_contents=$(< "$outputFile")
expected_file_contents=$(getExpectedFileContents "$expected_count")
assert "updated file contents matches expected value" "\"${actual_file_contents}\"==\"${expected_file_contents}\""

# Clean up after testing
# rm -rf "$cacheDir"
# rm -rf "$outputDir"
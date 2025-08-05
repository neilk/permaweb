#!/bin/bash
set -E

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

# shellcheck disable=SC1091
source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR

# Expected counts based on our test files
read -ra wc_output_arr <<< "$(wc "$testDir"/source/*.txt | tail -1)"
expected_line_count=${wc_output_arr[0]}
expected_word_count=${wc_output_arr[1]}

cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
outputDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)

# where we expect outputs to be generated
linecountFile="$outputDir/linecount.txt"
wordcountFile="$outputDir/deep/wordcount.txt"

# Test discovery first with heredoc
expectedRules=$(cat << 'EOF'
reducers/txt/linecount.txt|txt|linecount.txt|reducers/txt/linecount.txt/map.sh|reducers/txt/linecount.txt/reduce.sh
reducers/txt/deep/wordcount.txt|txt|deep/wordcount.txt|reducers/txt/deep/wordcount.txt/map.sh|reducers/txt/deep/wordcount.txt/reduce
EOF
)

# Sort the expected rules to ensure consistent comparison
expectedRules=$(echo "$expectedRules" | sort)

# Now get the actual discovered rules, and sort them too
rules=$(test_mapreduce_discovery 2 "reducers" | sort)

# assert that rules are identical
assert "Discovered rules match expected" "\"$rules\" == \"$expectedRules\""

# Run the map-reduce processes
doMapReduce "source" "$cacheDir" "reducers" "$outputDir"

# Verify both output files were created
assert "linecount output file was created" "-f $linecountFile"
assert "wordcount output file was created" "-f $wordcountFile"

# Check that the counts match expected values
actual_line_output=$(< "$linecountFile")
actual_word_output=$(< "$wordcountFile")

assert "line count output correct" "\"$actual_line_output\" == \"Total lines: $expected_line_count\""
assert "word count output correct" "\"$actual_word_output\" == \"Total words: $expected_word_count\""


# Clean up
rm -rf "$cacheDir"
rm -rf "$outputDir"
#!/bin/bash
set -E

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit 1

pwd

# shellcheck disable=SC1091
source "$(dirname "$testDir")/test/lib.sh"
trap 'handle_error $LINENO' ERR

# Test the find-map-reduce.sh script directly
echo "Testing map-reduce discovery logic..."

# Test 1: Basic discovery functionality
echo "=== Test 1: Basic Discovery ==="
cd map-reduce || exit 1
rules_output=$(test_mapreduce_discovery 1)

# Parse the single rule we expect
parse_mapreduce_rule "$rules_output"

# Test individual components
assert "Rule directory correct" "\"$RULE_DIR\" == \"reducers/txt/linecount.txt\""
assert "Rule extension correct" "\"$RULE_EXTENSION\" == \"txt\""
assert "Rule target correct (relative)" "\"$RULE_TARGET\" == \"linecount.txt\""
assert "Map script found" "-x \"$RULE_MAP_SCRIPT\""
assert "Reduce script found" "-x \"$RULE_REDUCE_SCRIPT\""

cd ..

# Test 2: Directory-based scripts
echo "=== Test 2: Directory-Based Scripts ==="
cd map-reduce-script-dir || exit 1
rules_output=$(test_mapreduce_discovery 1)

parse_mapreduce_rule "$rules_output"

assert "Directory-based map script" "\"$RULE_MAP_SCRIPT\" == \"reducers/txt/linecount.txt/map\""
assert "Directory-based reduce script" "\"$RULE_REDUCE_SCRIPT\" == \"reducers/txt/linecount.txt/reduce\""
assert "Target path is relative" "\"$RULE_TARGET\" == \"linecount.txt\""

cd ..

# Test 3: No map-reduce directories
echo "=== Test 3: No Map-Reduce Directories ==="
cd simple || exit 1
rules_output=$(test_mapreduce_discovery 0)
assert "No rules found when no map-reduce dirs exist" "-z \"$rules_output\""

cd ..

echo "✓ All map-reduce discovery tests passed!"
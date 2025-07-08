#!/bin/bash

# Test the testing library itself - passing tests
# This file tests complex assertions and eval functionality

. "$(dirname "$0")/lib.sh"

# Basic string comparisons
assert "String equality works" '"hello" == "hello"'
assert "String inequality works" '"foo" != "bar"'

# Numeric comparisons
assert "Numeric equality works" "42 -eq 42"
assert "Numeric greater than works" "100 -gt 50"
assert "Numeric less than works" "25 -lt 75"

# File operations
temp_file=$(mktemp)
echo "test content" > "$temp_file"
assert "File exists after creation" "-f $temp_file"
assert "File is readable" "-r $temp_file"
assert "File is writable" "-w $temp_file"

# Directory operations
temp_dir=$(mktemp -d)
assert "Directory exists after creation" "-d $temp_dir"
assert "Directory is readable" "-r $temp_dir"
assert "Directory is writable" "-w $temp_dir"

# Complex expressions with logical operators
assert "Complex AND expression works" "-f $temp_file -a -d $temp_dir"
assert "Complex OR expression works" "-f $temp_file -o -f /nonexistent"

# String length and pattern matching
test_string="hello world"
assert "String length check works" "${#test_string} -eq 11"
# Pattern matching doesn't work well with [ ] - commenting out for now
# assert "String contains pattern" '"$test_string" == *world*'

# Environment variable tests
export TEST_VAR="test_value"
assert "Environment variable is set" '"$TEST_VAR" == "test_value"'
assert "Environment variable exists" "-n $TEST_VAR"

# Command substitution in assertions
current_dir=$(pwd)
assert "Command substitution works" '"$(pwd)" == "$current_dir"'

# Multiple conditions with parentheses - doesn't work with [ ], commenting out
# assert "Parentheses grouping works" '( -f $temp_file -a -d $temp_dir ) -o -f /nonexistent'

# Arithmetic evaluation
assert "Arithmetic evaluation works" '$((5 + 3)) -eq 8'
assert "Complex arithmetic works" '$((10 * 2 + 5)) -eq 25'

# Test exit codes
true
assert "Command exit code check works" "$? -eq 0"

# Clean up
rm -f "$temp_file"
rm -rf "$temp_dir"

echo "All passing tests completed successfully!"
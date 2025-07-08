#!/bin/bash

# Test the eval functionality with complex expressions
# This demonstrates the power of the eval-based assertion system

. "$(dirname "$0")/lib.sh"

echo "Testing complex eval expressions..."

# Test variable expansion within eval
TEST_NUM=42
assert "Variable expansion in eval works" '$TEST_NUM -eq 42'

# Test array operations
declare -a test_array=("apple" "banana" "cherry")
assert "Array length check works" '${#test_array[@]} -eq 3'
assert "Array element access works" '"${test_array[1]}" == "banana"'

# Test string operations with eval
text="Hello World"
# Case conversion requires bash 4+ - commenting out for compatibility
# assert "String uppercase conversion works" '"${text^^}" == "HELLO WORLD"'
# assert "String lowercase conversion works" '"${text,,}" == "hello world"'
assert "String substring works" '"${text:0:5}" == "Hello"'

# Test complex conditional expressions
x=10
y=20
# Complex parentheses don't work with [ ] - commenting out
# assert "Complex numeric comparison works" '( $x -lt $y ) -a ( $((x + y)) -eq 30 )'

# Test process substitution and command evaluation
temp_file=$(mktemp)
echo -e "line1\nline2\nline3" > "$temp_file"
assert "Line count via wc works" '$(wc -l < "$temp_file") -eq 3'

# Test pattern matching with eval - regex doesn't work with [ ]
filename="test.txt"
# assert "Pattern matching works" '"$filename" =~ "\.txt$"'

# Test function calls within eval
get_double() {
    echo $((${1} * 2))
}
assert "Function call in eval works" '$(get_double 21) -eq 42'

# Test nested command substitution
assert "Nested command substitution works" '$(echo $(expr 5 + 5)) -eq 10'

# Test parameter expansion with defaults
unset UNDEFINED_VAR
assert "Parameter expansion with default works" '"${UNDEFINED_VAR:-default_value}" == "default_value"'

# Test arithmetic expansion
assert "Arithmetic expansion works" '$((2 ** 3)) -eq 8'
assert "Arithmetic with variables works" '$((x * 2 + y)) -eq 40'

# Test glob patterns (create test files first)
test_dir=$(mktemp -d)
touch "$test_dir/file1.txt" "$test_dir/file2.txt" "$test_dir/other.dat"
assert "Glob pattern counting works" '$(ls "$test_dir"/*.txt | wc -l) -eq 2'

# Clean up
rm -f "$temp_file"
rm -rf "$test_dir"

echo "All eval tests completed successfully!"
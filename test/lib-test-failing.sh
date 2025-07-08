#!/bin/bash

# Test the testing library itself - failing tests
# This file tests that the testing framework properly catches failures

. "$(dirname "$0")/lib.sh"

echo "Testing that the test framework properly catches failures..."
echo "Each test below should fail and exit with code 99"

# This test should fail - string inequality
assert "This should fail - strings are equal" '"hello" != "hello"'

# This test should never be reached due to the exit above
assert "This should never be reached" "1 -eq 1"

echo "If you see this message, the test framework is broken!"
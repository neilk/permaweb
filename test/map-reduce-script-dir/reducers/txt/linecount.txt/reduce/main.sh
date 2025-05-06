#!/usr/bin/env bash
# Reduce script for line counting
# Takes line counts from map stage and sums them up

# Record that we're running for test purposes
basename "$0" >> "$PERMAWEB_SCRIPT_RECORD"

# Get the script's directory to locate the header.txt file
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Sum all the line counts from the input
linecount=$(awk '{sum += $1} END {print sum}')

sed "s/XXXX/${linecount}/" < "${SCRIPT_DIR}/header.txt"
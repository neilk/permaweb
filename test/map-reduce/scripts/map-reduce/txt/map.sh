#!/usr/bin/env bash
# Map script for line counting
# Simply counts lines in a file and outputs the count

# Record that we're running for test purposes
basename "$0" >> "$PERMAWEB_SCRIPT_RECORD"

# Count the lines in the input file
wc -l | tr -d ' '
#!/usr/bin/env bash

# Record that we're running for test purposes
basename "$0" >> "$PERMAWEB_SCRIPT_RECORD"

# We are receiving a list of files on standard input. 
# Read their contents, which should be a single number on a single line, and then sum them up.
xargs awk '{ sum += $1 } END { print sum }' 
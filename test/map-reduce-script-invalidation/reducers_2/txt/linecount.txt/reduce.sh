#!/usr/bin/env bash
# Reduce script for line counting (version 2)
# Takes line counts from map stage and sums them up, then adds a prefix

# Record that we're running for test purposes
basename "$0" >> "$PERMAWEB_SCRIPT_RECORD"

# Sum all the line counts from the input and add a prefix to show it's version 2
xargs awk '{sum += $1} END {print "Total: " sum}'
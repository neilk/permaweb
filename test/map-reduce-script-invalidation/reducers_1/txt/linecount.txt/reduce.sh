#!/usr/bin/env bash
# Reduce script for line counting (version 1)
# Takes line counts from map stage and sums them up

# Record that we're running for test purposes
basename "$0" >> "$PERMAWEB_SCRIPT_RECORD"

# Sum all the line counts from the input - just the sum
awk '{sum += $1} END {print sum}'
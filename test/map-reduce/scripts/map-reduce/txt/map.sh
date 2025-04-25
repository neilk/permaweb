#!/usr/bin/env bash
# Map script for line counting
# Simply counts lines in a file and outputs the count

# Record that we're running for test purposes
if [[ -n "$PERMAWEB_MAP_RUN_COUNT" ]]; then
    export PERMAWEB_MAP_RUN_COUNT=$((PERMAWEB_MAP_RUN_COUNT + 1))
fi

# Count the lines in the input file
wc -l | tr -d ' '
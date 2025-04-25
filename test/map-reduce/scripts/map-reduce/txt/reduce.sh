#!/usr/bin/env bash
# Reduce script for line counting
# Takes line counts from map stage and sums them up

# Record that we're running for test purposes
if [[ -n "$PERMAWEB_REDUCE_RUN_COUNT" ]]; then
    export PERMAWEB_REDUCE_RUN_COUNT=$((PERMAWEB_REDUCE_RUN_COUNT + 1))
fi

# Sum all the line counts from the input
awk '{sum += $1} END {print sum}'
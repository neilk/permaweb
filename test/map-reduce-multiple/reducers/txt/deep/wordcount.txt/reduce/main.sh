#!/bin/bash

# Reduce script for summing word counts
# Reads multiple word counts and outputs the total
wordcount=$(xargs awk '{sum += $1} END {print sum}')

echo "Total words: $wordcount"
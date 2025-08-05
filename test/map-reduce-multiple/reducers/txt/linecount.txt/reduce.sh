#!/bin/bash

linecount=$(xargs awk '{sum += $1} END {print sum}')

echo "Total lines: $linecount"
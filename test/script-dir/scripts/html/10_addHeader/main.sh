#!/usr/bin/env bash

# Get the script's directory to locate the header.html file
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Read the input HTML from stdin
html=$(cat)

# Insert the header after the body tag
# This script demonstrates using a dependent file (header.html) in the same directory
header_content=$(cat "${SCRIPT_DIR}/header.html")
html_with_header=$(echo "$html" | sed -E "s|<body>|<body>\n${header_content}|g")

# Output the modified HTML
echo "$html_with_header"
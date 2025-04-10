#!/usr/bin/env bash

# To know which scripts ran, we output our path here.
realpath --relative-to="$PERMAWEB_SCRIPT_RECORD_BASE" "$(readlink -f "$0")" >> "$PERMAWEB_SCRIPT_RECORD"

# Get the script's directory to locate the header.html file
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# sed requires this for multiline content
escape_newlines() {
    awk '{printf "%s\\n", $0}' "$1"
}

# This script demonstrates using a dependent file (header.html) in the same directory
newline_escaped_header=$(escape_newlines "${SCRIPT_DIR}/header.html")


# Insert the header after the body tag
sed -E "s|<body>|<body>\n${newline_escaped_header}|g"
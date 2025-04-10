#!/usr/bin/env bash

# To know which scripts ran, we output our path here.
realpath --relative-to="$PERMAWEB_SCRIPT_RECORD_BASE" "$(readlink -f "$0")" >> "$PERMAWEB_SCRIPT_RECORD"

sed -E 's|([[:space:]]*)</head>|\1    <meta charset="UTF-8">\n\1</head>|g'
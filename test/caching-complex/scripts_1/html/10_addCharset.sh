#!/usr/bin/env bash

# Record that we ran
basename "$0" >> "$PERMAWEB_SCRIPT_RECORD"

sed -E 's|([[:space:]]*)</head>|\1    <meta charset="UTF-8">\n\1</head>|g'
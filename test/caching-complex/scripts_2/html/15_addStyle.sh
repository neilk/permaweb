#!/usr/bin/env bash

# Record that we ran
basename "$0" >> "$PERMAWEB_SCRIPT_RECORD"

# This is a comment added solely so the file will hash differently. However the output should be identical
# to its counterpart in "scripts_buggy"

sed -E 's|([[:space:]]*)</head>|\1    <link rel="stylesheet" type="text/css" href="/style.css">\n\1</head>|g'
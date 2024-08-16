#!/usr/bin/env bash

# Record that we ran
basename "$0" >> "$PERMAWEB_SCRIPT_RECORD"

sed -E 's|([[:space:]]*)</head>|\1    <link rel="stylesheet" type="text/css" href="/style.css">\n\1</head>|g'
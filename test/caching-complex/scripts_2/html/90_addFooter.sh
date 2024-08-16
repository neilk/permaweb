#!/usr/bin/env bash

# Record that we ran
basename "$0" >> "$PERMAWEB_SCRIPT_RECORD"

sed -E 's|([[:space:]]*)</body>|\1    <footer>Made with Permaweb</footer>\n\1</body>|g'
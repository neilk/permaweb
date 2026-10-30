#!/usr/bin/env bash
# Appends footer.html, a dependent file in the same directory, to the input.
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
cat -
cat "${SCRIPT_DIR}/footer.html"

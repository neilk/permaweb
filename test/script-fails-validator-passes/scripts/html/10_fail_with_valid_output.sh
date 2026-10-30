#!/usr/bin/env bash
# Emits well-formed output, then fails. permaweb must treat this as a failure.
cat
echo "<p>SHOULD-NOT-APPEAR</p>"
echo "script failed deliberately" >&2
exit 1

#!/bin/bash

#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <executable>" >&2
    exit 1
fi

EXECUTABLE="$1"

# Read stdin into a variable without using cat
read -d '' -r INPUT

# Run once, capturing output and using exit code to determine which to echo
OUTPUT=$("$EXECUTABLE" <<< "$INPUT") && echo "$OUTPUT" || echo "$INPUT"


# Create FIFOs
# ORIG_FIFO=$(mktemp -u)
# PROG_FIFO=$(mktemp -u)
# STATUS_FIFO=$(mktemp -u)
# mkfifo "$ORIG_FIFO" "$PROG_FIFO" "$STATUS_FIFO"

# # Clean up FIFOs on exit
# trap 'rm -f "$ORIG_FIFO" "$PROG_FIFO" "$STATUS_FIFO"' EXIT

# # Run executable and capture its status
# tee "$ORIG_FIFO" | "$EXECUTABLE" > "$PROG_FIFO"

# # Read status and choose appropriate output
# if [ "$(cat "$STATUS_FIFO")" -eq 0 ]; then
#     cat "$PROG_FIFO"
# else
#     cat "$ORIG_FIFO"
# fi
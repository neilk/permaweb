#!/usr/bin/env bash

# Usage: 
# pipeOrPass.sh executable < input.txt > output.txt

# Check if the executable is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <executable> <input file on stdin>"
  exit 1
fi

# Assign the first argument as the executable
executable="$1"

# Use a temporary file for tee
tmpfile=$(mktemp)

# Open file descriptor 3 and redirect it to a temporary file
exec 3> >(tee "$tmpfile")

# Use tee to duplicate the input, send one copy to the temporary file and another to the executable via FD 3
tee "$tmpfile" | "$executable" >&3

# Capture the exit code of the executable
exitCode=$?

# Close file descriptor 3
exec 3>&-

# After the execution, you can access the contents of the temporary file as needed
# Here we just output it for demonstration purposes
cat "$tmpfile"

# Clean up the temporary file
rm "$tmpfile"

# Output the exit code for verification (you can remove this line in production)
echo "Exit code of $executable: $exitCode"

# Return the exit code of the executable as the script's exit code
exit $exitCode

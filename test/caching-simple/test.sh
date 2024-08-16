#!/bin/bash
set -E

#
# Here we test what scripts and validations actually run. To do this, we modified the 
# scripts and validations to log their `basename` to a file supplied by environment variable.
#
# We do one runthrough where all scripts and validations succeed
# The second one should not trigger execution of any scripts or validations.
#

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR

warn "$0"

# Run the script the first time

inputPath=source/index.html
outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD
cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
"../../engine.sh" -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath"

# Test assertions
count=$(grep -c '<meta charset' "$outputPath")
assert "output has charset" "$count == 1"

count=$(grep -c '<h1' "$outputPath")
assert "output has h1" "$count == 1"

# The contents of PERMAWEB_SCRIPT_RECORD should simply be the list of scripts, in order.
actualScriptRecord=$(<"$PERMAWEB_SCRIPT_RECORD")
expectedScriptRecord=$(ls -1 "./scripts/html" | sort)
matched=false
if [ "$actualScriptRecord" == "$expectedScriptRecord" ]; then
    matched=true
fi

assert "first execution: all scripts ran" "$matched"


# ========

# Now, do it again, with the same cache directory, logging the scripts that ran to another file. 
# No script should run!
PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD
outputPath2=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
"../../engine.sh" -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath2"

# Test assertions
count=$(grep -c '<meta charset' "$outputPath2")
assert "output has charset" "$count == 1"

count=$(grep -c '<h1' "$outputPath2")
assert "output has h1" "$count == 1"

# No script should have run
actualScriptRecord2=$(<"$PERMAWEB_SCRIPT_RECORD")
assert "second execution: no scripts ran" "-z $actualScriptRecord2"
#!/bin/bash
set -E

#
# Here we test what scripts and validations actually run. To do this, we modified the 
# scripts and validations to log their `basename` to a file supplied by environment variable.
#
# We do one runthrough where all scripts and validations succeed. Because everything is then cached,
# the second one should not trigger execution of any scripts or validations.
#

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR

# Run the script the first time

inputPath=source/index.html
outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD
cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
"../../single.sh" -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath"

# Test assertions
count=$(grep -c '<meta charset' "$outputPath")
assert "output has charset" "$count == 1"

count=$(grep -c '<h1' "$outputPath")
assert "output has h1" "$count == 1"

# The contents of PERMAWEB_SCRIPT_RECORD should be as follows. 
# The first "html" is the initial validation.
# Then, all subsequent scripts are run, and their html is validated.
expectedScriptRecord=$(cat << 'EOF'
html
10_addCharset.sh
html
20_addH1.sh
html
EOF
)

scriptRecordMatch=false
if diff <(echo "$expectedScriptRecord") "$PERMAWEB_SCRIPT_RECORD" > /dev/null; then
    scriptRecordMatch=true
fi

assert "first execution: all scripts and validations ran" "$scriptRecordMatch == true"


# ========

# Now, do it again, with the same cache directory, logging the scripts that ran to another file. 
PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD
outputPath2=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
"../../single.sh" -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath2"

# Test assertions
count=$(grep -c '<meta charset' "$outputPath2")
assert "output has charset" "$count == 1"

count=$(grep -c '<h1' "$outputPath2")
assert "output has h1" "$count == 1"

# no script or validation should have run
actualScriptRecord2=$(<"$PERMAWEB_SCRIPT_RECORD")
assert "second execution: no scripts or validations ran" "-z $actualScriptRecord2"

#!/bin/bash
set -E

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR


warn "$0"

# Test for directory-based scripts with dependent files

# Run permaweb, with an environment variable, PERMAWEB_SCRIPT_RECORD, to tell it to record what got executed

inputPath=source/index.html
outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD
cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
../../permaweb -d -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath"

warn "PERMAWEB_SCRIPT_RECORD: $PERMAWEB_SCRIPT_RECORD"
warn "script_record:"
cat "$PERMAWEB_SCRIPT_RECORD"
warn "end script record"

# The contents of PERMAWEB_SCRIPT_RECORD should be as follows. 
# The first "html" is the initial validation.
# Then, all subsequent scripts are run, and their html is validated.
expectedScriptRecord=$(cat << 'EOF'
html
10_addHeader/main.sh
html
15_addCharset.sh
html
20_addFooter/main
html
EOF
)

scriptRecordMatch=false
if diff <(echo "$expectedScriptRecord") "$PERMAWEB_SCRIPT_RECORD" > /dev/null; then
    scriptRecordMatch=true
fi

assert "all scripts and validations ran" "$scriptRecordMatch == true"



# Common assertions
assert_cache_ok "$cacheDir"

# Test assertions
headerCount=$(grep -c 'Directory-Based Script Test' "$outputPath")
assert "header was added from the dependent file" "$headerCount == 1"

# Store the object hash of the script's output for comparison later
firstRunObj=$(find "$cacheDir/exec" -name "1" -print0 | xargs -0 readlink)

# Modify the header.html file to test invalidation
sed -i.bak 's/Directory-Based Script Test/MODIFIED Header Test/g' scripts/html/10_addHeader/header.html

# Run again - should use new header
outputPath2=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
../../permaweb -d -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath2"

# Verify the header was updated (cache was invalidated)
modifiedCount=$(grep -c 'MODIFIED Header Test' "$outputPath2")
assert "header was updated after dependent file change" "$modifiedCount == 1"

# Get the new object hash to confirm it changed
secondRunObj=$(find "$cacheDir/exec" -name "1" -print0 | xargs -0 readlink)
assert "cache object changed when dependent file changed" "$firstRunObj != $secondRunObj"

# Cleanup
rm -f "$outputPath" "$outputPath2" scripts/html/10_addHeader/header.html.bak

warn "All tests passed!"
exit 0
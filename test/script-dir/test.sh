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

# This is so the tests can tell us if they ran
echo "trying $0"
PERMAWEB_SCRIPT_RECORD_BASE=$testDir
export PERMAWEB_SCRIPT_RECORD_BASE
PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD

cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)

# Function to create a header file with unique content
create_unique_header() {
    local timestamp=$(date +%s)
    local unique_id="header-test-$timestamp"
    
    cat > scripts/html/10_addHeader/header.html << EOF
<header>
    <h1>Directory-Based Script Test - HEADER</h1>
    <nav>
        <ul>
            <li><a href="/">Home</a></li>
            <li><a href="/about">About</a></li>
            <li class="unique-marker" id="$unique_id">Unique Test ID</li>
        </ul>
    </nav>
</header>
EOF
    echo "$unique_id"
}

# First run with initial header
unique_id1=$(create_unique_header)
outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
../../permaweb -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath"

warn "PERMAWEB_SCRIPT_RECORD: $PERMAWEB_SCRIPT_RECORD"
warn "script_record:"
cat "$PERMAWEB_SCRIPT_RECORD"
warn "end script record"

# The contents of PERMAWEB_SCRIPT_RECORD should be as follows. 
# The first "html" is the initial validation.
# Then, all subsequent scripts are run, and their html is validated.
expectedScriptRecord=$(cat << 'EOF'
scripts/html/10_addHeader/main.sh
scripts/html/15_addCharset.sh
scripts/html/20_addFooter/main
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
cat "$outputPath"
grep_result=$(grep -c "$unique_id1" "$outputPath")
assert "header was added with the unique ID" "$grep_result == 1"

# Store the object hash of the script's output for comparison later
firstRunObj=$(find "$cacheDir/exec" -name "1" -print0 | xargs -0 readlink)

# Create a second header with different unique content
unique_id2=$(create_unique_header)
assert "unique IDs are different" "\"$unique_id1\" != \"$unique_id2\""

# Run again - should use new header
outputPath2=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
../../permaweb -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath2"

# Verify the header was updated (cache was invalidated)
grep_result2=$(grep -c "$unique_id2" "$outputPath2")
assert "header was updated with new unique ID" "$grep_result2 == 1"

# Get the new object hash to confirm it changed
secondRunObj=$(find "$cacheDir/exec" -name "1" -print0 | xargs -0 readlink)
assert "cache object changed when dependent file changed" "$firstRunObj != $secondRunObj"

# Cleanup
rm -f "$outputPath" "$outputPath2"

warn "All tests passed!"
exit 0
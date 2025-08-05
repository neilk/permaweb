#!/bin/bash

# This test demonstrates that the cache is invalidated when 
# the script directory content changes.

set -E

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR

# Test for directory-based scripts with dependent files

# Run permaweb, with an environment variable, PERMAWEB_SCRIPT_RECORD, to tell it to record what got executed

inputPath=source/index.html

# This is so the tests can tell us if they ran
PERMAWEB_SCRIPT_RECORD_BASE=$testDir
export PERMAWEB_SCRIPT_RECORD_BASE
PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD

cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)

# Function to create a header file with unique content
create_unique_header() {
    local unique_id
    unique_id=$(generate_random_string 10)
    
    cat > scripts/html/10_addHeader/header.html << EOF
<header>
    <h1>Directory-Based Script Test</h1>
    <nav>
        <ul>
            <li><a href="/">Home</a></li>
            <li><a href="/about">About</a></li>
            <li>Unique Test ID: $unique_id</li>
        </ul>
    </nav>
</header>
EOF
    echo "$unique_id"
}

# First run with initial header
unique_id1=$(create_unique_header)
outputPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
../../single.sh -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath"

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
grep_result=$(grep -c "$unique_id1" "$outputPath")
assert "header was added with the unique ID" "$grep_result == 1"

# Create a second header with different unique content
unique_id2=$(create_unique_header)
assert "unique IDs are different" "\"$unique_id1\" != \"$unique_id2\""

# Run again - should use new header
outputPath2=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
../../single.sh -c "$cacheDir" -s "./scripts" "$inputPath" > "$outputPath2"

# Since the header is part of the script directory content, the cache path should have 
# been different, and therefore the cache should have been invalidated
grep_result2=$(grep -c "$unique_id2" "$outputPath2")
assert "header was updated with new unique ID" "$grep_result2 == 1"

# Cleanup
rm -f "$outputPath" "$outputPath2"

exit 0

#!/bin/bash
set -E

#
# Here we test what scripts and validations actually run, if the content of the scripts change. 
# This simulates what happens during development. We want to cache results as much as possible. 
#
# We do one runthrough where some scripts and validations fail.
#
# We then swap out a different script directory, with some fixes, and run it again.
# The scripts that successfully ran before any change should not run because all results are cached. 
# Scripts that have changed should run.
# Scripts that receive different output from before should also run.

testDir=$(dirname -- "$( readlink -f -- "$0"; )");
cd "$testDir" || exit

source "$(dirname "$testDir")/lib.sh"
trap 'handle_error $LINENO' ERR

# Run the script the first time

inputPath=source/index.html
outputPath1=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD
cacheDir=$(mktemp -d "/tmp/permaweb.XXXXX" || exit 1)
"../../engine.sh" -c "$cacheDir" -s "./scripts_1" "$inputPath" > "$outputPath1"

# The contents of PERMAWEB_SCRIPT_RECORD should be as follows. 
# The first "html" is the initial validation.
# Then, all subsequent scripts are run, and their html is validated.
expectedScriptRecord1=$(cat << 'EOF'
html
10_addCharset.sh
html
15_addStyle.sh
html
17_addLanguage.sh
html
20_addH1.sh
html
30_addNavigation.sh
html
90_addFooter.sh
html
EOF
)

scriptRecordMatch1=false
if diff <(echo "$expectedScriptRecord1") "$PERMAWEB_SCRIPT_RECORD" > /dev/null; then
    scriptRecordMatch1=true
fi

assert "first execution: all scripts and validations ran" "$scriptRecordMatch == true"


# ========

# Now, do it again, with the same cache directory, logging the scripts that ran to another file,
# but with an altered scripts directory. While they are different files, most of them should hash 
# identically to the previous scripts directory.
PERMAWEB_SCRIPT_RECORD=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
export PERMAWEB_SCRIPT_RECORD
outputPath2=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
"../../engine.sh" -c "$cacheDir" -s "./scripts_2" "$inputPath" > "$outputPath2"

# This is what we expect to run:
# addStyle runs, because its script content is different now.
# (subsequent scripts do NOT run, because the output was the same, and their 
#  script content is the same).
# addNavigation runs, because its content is different.
# addFooter also runs, because the output from addNavigation is different, so its input is now different.
expectedScriptRecord2=$(cat << 'EOF'
15_addStyle.sh
html
30_addNavigation.sh
html
90_addFooter.sh
html
EOF
)

scriptRecordMatch2=false
if diff <(echo "$expectedScriptRecord2") "$PERMAWEB_SCRIPT_RECORD" > /dev/null; then
    scriptRecordMatch2=true
fi

assert "second execution: only some scripts and validations ran" "$scriptRecordMatch2 == true"
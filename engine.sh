#!/bin/bash

# We expect a "scripts" directory to exist, with directories for each file extension we 
# want to handle. Each of these directories should contain scripts that will be executed
# on each file of the corresponding extension. Each script must have executable permissions 
# or it will be ignored. The scripts should be named with a number prefix, so that they 
# are executed in the correct order.
#
# If any script returns a non-success exit code, its output is ignored.
#
# For example, if we want to handle html files, we would have the following structure:
# scripts/        contains one directory per file extension
#   - html        for example
#       - 01.sh      contains a script that will be executed on each html file
#       - 02.js      a javascript script that will be executed on each html file, after 01.sh
#       - 02.txt     will not be executed. Presumably 02.js uses it.
#       - 03.sh      will be executed on the output of 02.js

warn() {
    echo "$@" >&2;
}

MAIN_SCRIPTS_DIR="./scripts"

filename="$1"
extension="${filename##*.}"

if [[ ! -f "$filename" ]]; then
    warn "File $filename does not exist";
    exit 1;
fi

output="$(cat "$filename")"

if [[ -n "${extension}" ]]; then
    scriptsDir="${MAIN_SCRIPTS_DIR}/${extension}"; 
    if [[ -d "${scriptsDir}" ]]; then     
        for f in $(ls "${scriptsDir}" | sort); do
            if [[ ! -x "${scriptsDir}/${f}" ]]; then
                continue
            fi
            warn "running ${scriptsDir}/${f}";
            newOutput=$(echo "${output}" | "${scriptsDir}/${f}");
            if [[ $? -eq 0 ]]; then
                output="${newOutput}"
            fi
        done
    fi
fi

echo "$output"
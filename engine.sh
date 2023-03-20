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

mkdir -p ".engine/cache"

MAIN_SCRIPTS_DIR="./scripts"

filename="$1"
extension="${filename##*.}"

if [[ ! -f "$filename" ]]; then
    warn "File $filename does not exist";
    exit 1;
fi




getHashFile() {
    sha1sum "$1" | cut -d' ' -f1
}

getHashString() {
    echo "$1" | sha1sum | cut -d' ' -f1
}

getResultPath() {
    warn "";
    warn "========";

    inputPath="$1"
    script="$2"
    cacheKey="$(getHashFile "$inputPath")_$(getHashFile "$script")"
    cachePath=".engine/cache/${cacheKey}"
    returnCode=0

    warn "trying ${script}";
    
    if [[ -L "${cachePath}" ]]; then
        warn "this previously succeeded";
        readlink -f "${cachePath}";
        return 0;
    else 
        if [[ -f "${cachePath}" ]]; then
            warn "this previously failed, or failed to validate; not running ${script}";
            echo "FAILED";
            return 1;
        else 
            warn "running ${script} on ${inputPath}";
            
            # now make a temp file 
            tempPath=$(mktemp -q /tmp/permaweb.XXXXXX || exit 1)
            warn "writing to ${tempPath}";
 
            # Set trap to clean up file
            trap 'rm -f -- "$tempPath"' EXIT
 
            # continue with script
            warn "Using $tempPath ..."

            # execute script
            "${script}" < "${inputPath}" > "${tempPath}" 2> >(tee -a "${cachePath}" >&2) 
            if [[ $? -eq 0 ]]; then
                warn "ran successfully";

                # TODO validate other things than HTML?
                warn "validating...";
                npx html-validate "$1" 1>&2
                if [[ $? -ne 0 ]]; then
                    warn "Script ${script} produced invalid html";
                    rm -f -- "$tempPath"
                    trap - EXIT
                    warn "error is $?";
                    return $?;
                fi

                objectPath="$(pwd)/.engine/object/$(getHashFile "${tempPath}")";
                if [[ ! -f "${objectPath}" ]]; then
                    warn "creating object ${objectPath}";
                    mv "${tempPath}" "${objectPath}";
                else
                    warn "object ${objectPath} already exists";
                    rm -f -- "$tempPath"
                    trap - EXIT
                fi

                rm "${cachePath}";  # remove the error file
                ln -s "${objectPath}" "${cachePath}";
                readlink -f "${cachePath}";
                return 0;
            fi
        fi
    fi
    warn "should never reach here -- failed";
    return 1;
}

inputPath="${filename}";

if [[ -n "${extension}" ]]; then
    scriptsDir="${MAIN_SCRIPTS_DIR}/${extension}"; 
    if [[ -d "${scriptsDir}" ]]; then     
        for f in $(ls "${scriptsDir}" | sort); do
            if [[ ! -x "${scriptsDir}/${f}" ]]; then
                continue;
            fi
            script="${scriptsDir}/${f}";
            warn "Current input path is ${inputPath}";

            newInputPath=$(getResultPath "${inputPath}" "${script}");
            returnCode=$?
            warn "return code from result is ${returnCode}";
            if [[ $returnCode -ne 0 ]]; then
                warn "Script ${script} failed";
                continue;
            fi

            warn "new input path is ${newInputPath}";
            inputPath="${newInputPath}";
        done
    fi
fi

cat "$inputPath";
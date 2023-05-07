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

debug() {
    if "${DEBUG}"; then
        warn "$@"
    fi
}

# create directories
engineDir="$(pwd)/.engine";   # engine state
cacheDir="${engineDir}/cache";  # results of scripts on inputs
objectDir="${engineDir}/object";  # content-addressable objects
mkdir -p "${engineDir}"         
mkdir -p "${cacheDir}"    
mkdir -p "${objectDir}"   

# defaults
DEBUG=false
scriptsDir="./scripts"

# parse options
while getopts ":s:d" opt; do
    case "${opt}" in
        d)
            DEBUG=true
            ;;
        s)
            scriptsDir="${OPTARG}"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

# parse positional arguments after options
shift $((OPTIND-1))

filename="$1"
if [[ -z "${filename}" ]]; then
    warn "No filename provided";
    exit 1;
fi
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
    debug "";
    debug "========";

    inputPath="$1"
    script="$2"
    cacheKey="$(getHashFile "$inputPath")_$(getHashFile "$script")"
    cachePath="${cacheDir}/${cacheKey}"
    returnCode=0

    debug "trying ${script}";
    
    if [[ -L "${cachePath}" ]]; then
        debug "this previously succeeded";
        readlink -f "${cachePath}";
        return 0;
    else 
        if [[ -f "${cachePath}" ]]; then
            debug "this previously failed, or failed to validate; not running ${script}";
            debug "FAILED";
            return 1;
        else 
            debug "running ${script} on ${inputPath}";
            
            # now make a temp file 
            tempPath=$(mktemp -q /tmp/permaweb.XXXXXX || exit 1)
            debug "writing to ${tempPath}";
 
            # Set trap to clean up file
            trap 'rm -f -- "$tempPath"' EXIT
 
            # continue with script
            debug "Using $tempPath ..."

            # execute script
            "${script}" < "${inputPath}" > "${tempPath}" 2> >(tee -a "${cachePath}" >&2) 
            scriptReturnCode=$?
            # echo " == OUTPUT == " 
            #cat "${tempPath}"
            #echo " == END OUTPUT == " 

            if [[ $scriptReturnCode -eq 0 ]]; then
                debug "ran successfully";
                rm "${cachePath}";  # remove error file

                # TODO validate other things than HTML?
                debug "validating...";
                # TODO why does this try to make a network connection? On a plane, with busted wifi,
                # this blocked. But if wifi was turned off it succeeded
                npx html-validate "${tempPath}" 1>&2
                validationError=$?
                if [[ "${validationError}" -ne 0 ]]; then
                    warn "Script ${script} produced invalid html";
                    rm -f -- "$tempPath"
                    trap - EXIT
                    debug "error is ${validationError}";
                    return "${validationError}";
                fi

                objectPath="${objectDir}/$(getHashFile "${tempPath}")";
                if [[ ! -f "${objectPath}" ]]; then
                    debug "creating object ${objectPath}";
                    mv "${tempPath}" "${objectPath}";
                else
                    debug "object ${objectPath} already exists";
                    rm -f -- "$tempPath"
                    trap - EXIT
                fi

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
    scriptsDir="${scriptsDir}/${extension}"; 
    if [[ -d "${scriptsDir}" ]]; then

        # The first "script" is a no-op, cat, because we need to validate the file as is.
        scripts=('/bin/cat');
        while IFS=  read -r -d $'\0' script; do
            scripts+=("${script}")
        done < <(find "${scriptsDir}" -type f -perm +111 -prune -print0 | sort -z)

        for script in "${scripts[@]}"; do
            debug "Current input path is ${inputPath}";

            newInputPath=$(getResultPath "${inputPath}" "${script}");
            returnCode=$?
            debug "return code from result is ${returnCode}";
            if [[ $returnCode -ne 0 ]]; then
                warn "Script ${script} failed; skipping";
                continue;
            fi

            debug "new input path is ${newInputPath}";
            inputPath="${newInputPath}";
        done
    fi
fi

# This is either the original input path or the result of a series of scripts

# TODO it seems very wasteful to copy with /bin/cat when it's say, a TTF file we're not doing anything with

# Also, it seems not great that we only copy over, we don't remove files when they're removed
# hmmmm we might need a more abstract way of expressing the target, instead of output redirection?
# or, make sure the engine.sh only runs when there are scripts to execute; otherwise we do a fast link
/bin/cat "$inputPath";
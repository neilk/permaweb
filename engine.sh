#!/bin/bash

# MAYBE:
# what if we did the cache this way
# input_hash/command_hash/
# rc -> text file containing a single integer (or a binary file?); return code
# 1 -> link to stdout object
# 2 -> link to stderr object

warn() {
    echo "$@" >&2;
}

debug() {
    if "${DEBUG}"; then
        warn "$@"
    fi
}

# defaults
rootDir=$(pwd);
DEBUG=false

# parse options
while getopts ":r:d" opt; do
    case "${opt}" in
        d)
            DEBUG=true
            ;;
        r)
            rootDir="${OPTARG}"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

# create directories
# (This should be set up in the makefile, we shouldn't have to check this every invocation?)
engineDir="${rootDir}/.engine"
cacheDirName="cache";
objectDirName="object";
cacheDir="${engineDir}/${cacheDirName}";  # results of scripts on inputs
objectDir="${engineDir}/${objectDirName}";  # content-addressable objects
mkdir -p "${engineDir}"         
mkdir -p "${cacheDir}"    
mkdir -p "${objectDir}"

scriptsDir="${rootDir}/scripts"

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

# given a file, get the hash
getFileHash() {
    sha1sum "$1" | cut -d' ' -f1
}


# If command succeeds, return output
# If command fails, return input
pipeOrPass() {
    local tmp_input tmp_output
    
    tmp_input=$(mktemp)
    tmp_output=$(mktemp)
    
    trap 'rm -f "$tmp_input" "$tmp_output"' EXIT

    cat > "$tmp_input"
    
    if "$@" < "$tmp_input" > "$tmp_output"; then
        cat "$tmp_output"
    else
        cat "$tmp_input"
    fi
}


# Makes an entry in the content-aware cache
contentCache() {
    local sourcePath linkPath objectPath
    sourcePath=$1
    linkPath=$2
    objectPath="${objectDir}/$(getFileHash "${sourcePath}")";
    if [[ ! -f "${objectPath}" ]]; then
        mv "${sourcePath}" "${objectPath}"
    fi
    ln -s "${objectPath}" "${linkPath}"
}


# Given an input path and a script;
# Always prints the (cached) stderr to stderr.
# Does not print the content to stdout; it prints the path of the resulting content.
# Returns the exit code of the script, and/or any validation.
getResultPath() {
    debug "";
    debug "========";

    local inputPath script
    inputPath="$1"
    script="$2"

    local cachePath cachedExitCodePath cachedStdoutPath cachedStderrPath
    cachePath="${cacheDir}/$(getFileHash "$inputPath")/$(getFileHash "$script")"
    cachedExitCodePath="${cachePath}/exit"
    cachedStdoutPath="${cachePath}/1"
    cachedStderrPath="${cachePath}/2"
    
    debug "trying ${script}";

    # If we have never run this before, do so and cache the results
    if [[ ! -s "${cachedExitCodePath}" ]]; then
        # we have never run this before
        debug "running ${script} on ${inputPath}";

        mkdir -p "${cachePath}"

        local tempStdoutPath tempStderrPath
        tempStdoutPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
        trap 'rm -f -- "$tempStdoutPath"' EXIT
        tempStderrPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
        trap 'rm -f -- "$tempStderrPath"' EXIT

        debug "writing 1 > ${tempStdoutPath}  2 > ${tempStderrPath}";

        # execute script
        local exitCode
        "${script}" < "${inputPath}" > "${tempStdoutPath}" 2>"${tempStderrPath}"
        exitCode=$?

        # TODO cache the validator
        # validate, if possible. This can also fail the script
        local validator
        validator="validators/${extension}"
        if [[ -x "$validator" ]]; then
            "${validator}" "${tempStdoutPath}" 1>&2 2>>"${tempStderrPath}"
            exitCode=$?
        fi

        echo "${exitCode}" > "${cachedExitCodePath}"
        contentCache "${tempStdoutPath}" "${cachedStdoutPath}";
        contentCache "${tempStderrPath}" "${cachedStderrPath}";
    fi

    # Now we definitely have some output in the cache, even if it failed
    cachedExitCode=$(<"${cachedExitCodePath}");
    if [[ "${cachedExitCode}" -eq 0 ]]; then
        if [[ -e "${cachedStdoutPath}" ]]; then
            readlink "${cachedStdoutPath}"
        fi
        if [[ -e $cachedStderrPath ]]; then
            cat "${cachedStderrPath}" >&2
        fi
    fi
    return "${cachedExitCode}"
}

# Sometimesa a script very late in the chain will need to know the original filename - for instance, something 
# that builds navigation. We pass this in an environment variable.
PERMAWEB_SOURCE_PATH=$(realpath -s --relative-to=source "${filename}");
export PERMAWEB_SOURCE_PATH;

inputPath=${filename};

# Build the array of scripts
scripts=();
if [[ -n "${extension}" ]]; then
    if [[ -d "${scriptsDir}" ]]; then

        # The first "script" is a no-op, cat, because we need to validate the file as is.
        scripts=('/bin/cat');
        while IFS=  read -r -d $'\0' script; do
            scripts+=("${script}")
        done < <(find "${scriptsDir}" -type f -perm +111 -prune -print0 | sort -z)

        # iterate through the array of scripts on this content
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
cat "$inputPath";
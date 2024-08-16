#!/bin/bash
# set -E
#
#handle_error() {
#    local retval=$?
#    local line=$1
#    echo "Failed at $line: $BASH_COMMAND"
#    exit $retval
#}
#trap 'handle_error $LINENO' ERR


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
while getopts "dr:c:" opt; do
    case "${opt}" in
        d)
            DEBUG=true
            ;;
        r)
            rootDir="${OPTARG}"
            ;;
        c)
            cacheDir="${OPTARG}"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

# Allow directories relative to current working directory
if [[ ! $rootDir = /* ]]; then
    rootDir="$(pwd)/$rootDir"
fi
if [[ -z ${cacheDir:-} ]]; then
    # cacheDir was not set
    cacheDir="$rootDir/.cache"
else 
    # cacheDir is set. We just make sure relative directories work
    if [[ ! $cacheDir = /* ]]; then
        cacheDir="$(pwd)/$cacheDir"
    fi
fi

# create directories
# (This should be set up in the makefile, we shouldn't have to check this every invocation?)
execCacheDir="${cacheDir}/exec";  # results of scripts on inputs
objectCacheDir="${cacheDir}/object";  # content-addressable objects
mkdir -p "${cacheDir}"         
mkdir -p "${execCacheDir}"    
mkdir -p "${objectCacheDir}"

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

# Makes an entry in the content-aware cache
contentCache() {
    local sourcePath linkPath objectPath
    sourcePath=$1
    linkPath=$2
    objectPath="${objectCacheDir}/$(getFileHash "${sourcePath}")";
    if [[ ! -f "${objectPath}" ]]; then
        mv "${sourcePath}" "${objectPath}"
    fi
    local relativeObjectPath
    relativeObjectPath=$(realpath -s --relative-to="$(dirname "${linkPath}")" "${objectPath}")
    ln -s "${relativeObjectPath}" "${linkPath}"
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
    cachePath="${execCacheDir}/$(getFileHash "$inputPath")/$(getFileHash "$script")"
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

        # TODO rather than look up the validator every time, somehow cache that
        # validate, if possible. This can also fail the script.
        # Validators must consume on stdin, and return an exit code corresponding to validity.
        local validator
        validator="$scriptsDir/validators/${extension}"
        debug "validator is $validator"
        if [[ -x "$validator" ]]; then
            debug "running validator"
            "${validator}" < "${tempStdoutPath}" 1>&2 2>>"${tempStderrPath}"
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
            echo "$(dirname "${cachedStdoutPath}")/$(readlink "${cachedStdoutPath}")"
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
    if [[ -d "${scriptsDir}/${extension}" ]]; then        
        # The first "script" is a no-op, cat, because we need to validate the file as is.
        scripts=('/bin/cat');
        while IFS=  read -r -d $'\0' script; do
            scripts+=("${script}")
        done < <(find "${scriptsDir}/${extension}" -type f -perm +111 -prune -print0 | sort -z)

        # iterate through the array of scripts on this content
        for script in "${scripts[@]}"; do
            debug "Current input path is ${inputPath}";

            newInputPath=$(getResultPath "${inputPath}" "${script}");
            returnCode=$?
            debug "return code from result is ${returnCode}";
            if [[ $returnCode -ne 0 ]]; then
                debug "Script ${script} failed; skipping";
                continue;
            fi

            debug "new input path is ${newInputPath}";
            inputPath="${newInputPath}";
        done
    fi
fi

# This is either the original input path or the result of a series of scripts
debug "input path is ${inputPath}"
cat "$inputPath";
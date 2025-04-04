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
DEBUG=false
scriptsDir="scripts"
cacheDir=".cache"

# parse options
while getopts "ds:c:" opt; do
    case "${opt}" in
        d)
            DEBUG=true
            ;;
        s)
            scriptsDir="${OPTARG}"
            ;;
        c)
            cacheDir="${OPTARG}"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

# Allow specified directories to be relative
if [[ ! $scriptsDir = /* ]]; then
    scriptsDir="$(pwd)/$scriptsDir"
fi

if [[ ! $cacheDir = /* ]]; then
    cacheDir="$(pwd)/$cacheDir"
fi

debug "scriptsDir: $scriptsDir  cacheDir $cacheDir"



# create directories
# (This should be set up in the makefile, we shouldn't have to check this every invocation?)
execCacheDir="${cacheDir}/exec";  # results of scripts on inputs
objectCacheDir="${cacheDir}/object";  # content-addressable objects
mkdir -p "${cacheDir}"         
mkdir -p "${execCacheDir}"    
mkdir -p "${objectCacheDir}"

# parse positional arguments after options
shift $((OPTIND-1))

# check for filename
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

# Makes an entry in the content-addressed cache
# This is actually just a link to the object cache, which contains all unique content. There may be
# many entries in the content cache that point to the same object.
cache() {
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


# Given an input path and a script, obtain the complete results - stdout, stderr, exit code -
# as if we ran that script and validation on exactly that input. This may be obtained
# from cache. The cache is keyed by the hashed content of the input file and script file.
#
# So, for the script && validation:
#   Echoes the path to a file caching the stdout;
#   Echoes the stderr to stderr.
#   Returns the exit code of the script && validation.
getCachedValidatedResultPath() {
    debug "";
    debug "========";

    local contentPath script
    contentPath="$1"
    script="$2"

    local cachePath cachedExitCodePath cachedStdoutPath cachedStderrPath
    cachePath="${execCacheDir}/$(getFileHash "$contentPath")/$(getFileHash "$script")"
    cachedExitCodePath="${cachePath}/exit"
    cachedStdoutPath="${cachePath}/1"
    cachedStderrPath="${cachePath}/2"
    
    debug "trying ${script}";

    # If we have never run this before, do so and cache the results
    if [[ ! -s "${cachedExitCodePath}" ]]; then
        # we have never run this before
        debug "running ${script} on ${contentPath}";

        mkdir -p "${cachePath}"

        local tempStdoutPath tempStderrPath
        tempStdoutPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
        trap 'rm -f -- "$tempStdoutPath"' EXIT
        tempStderrPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
        trap 'rm -f -- "$tempStderrPath"' EXIT

        debug "writing 1 > ${tempStdoutPath}  2 > ${tempStderrPath}";

        # execute script
        local exitCode
        debug "${script} < ${contentPath} > ${tempStdoutPath} 2>${tempStderrPath}"
        "${script}" < "${contentPath}" > "${tempStdoutPath}" 2>"${tempStderrPath}"
        exitCode=$?

        if [[ -n "$validator" ]]; then
            debug "running validator ${validator}";
            "${validator}" < "${tempStdoutPath}" 1>&2 2>>"${tempStderrPath}"
            exitCode=$?
        fi

        echo "${exitCode}" > "${cachedExitCodePath}"
        cache "${tempStdoutPath}" "${cachedStdoutPath}";
        cache "${tempStderrPath}" "${cachedStderrPath}";
    fi

    # Now we definitely have some output in the cache, even if it failed
    cachedExitCode=$(<"${cachedExitCodePath}");
    if [[ "${cachedExitCode}" -eq 0 ]]; then
        if [[ -e "${cachedStdoutPath}" ]]; then
            echo "$(dirname "${cachedStdoutPath}")/$(readlink "${cachedStdoutPath}")"
        fi
    fi
    if [[ -e $cachedStderrPath ]]; then
        cat "${cachedStderrPath}" >&2
    fi
    return "${cachedExitCode}"
}

# Get the validator for this extension, if there is one
validatorsDir="$scriptsDir/validators"
if [[ -d "$validatorsDir" ]]; then
    validatorPath="${validatorsDir}/${extension}"
    if [[ -f "$validatorPath" && -x "$validatorPath" ]]; then
        validator="$validatorPath"
    fi
fi

# Build the array of scripts
scripts=();
if [[ -n "${extension}" ]]; then
    if [[ -d "${scriptsDir}/${extension}" ]]; then        
        # The first "script" is a no-op, cat, because we need to validate the file as is.
        scripts=('/bin/cat');
        while IFS=  read -r -d $'\0' script; do
            scripts+=("${script}")
        done < <(find "${scriptsDir}/${extension}" -type f -perm -u=x -prune -print0 | sort -z)
    fi
fi

# Sometimes a script very late in the chain will need to know the original path - for instance, something 
# that builds navigation, involving files in the same directory. We pass this in an environment variable.
PERMAWEB_SOURCE_PATH=$(realpath -s "${filename}");
export PERMAWEB_SOURCE_PATH;

# Iterate through the array of scripts for this content. If a script fails, discard its results. 
# Eventually we will have a path to a file that represents only the successful transformations of the original file.
contentPath=${filename};
for script in "${scripts[@]}"; do
    debug "Current input path is ${contentPath}";

    newContentPath=$(getCachedValidatedResultPath "${contentPath}" "${script}");
    returnCode=$?
    debug "return code from result is ${returnCode}";
    if [[ $returnCode -ne 0 ]]; then
        debug "Script ${script} failed; skipping";
        continue;
    fi

    debug "new input path is ${newContentPath}";
    contentPath="${newContentPath}";
done

# Print the successful results of the transformations
debug "input path is ${contentPath}"
cat "$contentPath";

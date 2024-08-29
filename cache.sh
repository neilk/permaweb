#!/usr/bin/env bash

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

# default to ".cache" or PERMAWEB_CACHE_DIR
cacheDir="${PERMAWEB_CACHE_DIR:-.cache}"

# parse options
while getopts "d" opt; do
    case "${opt}" in
        d)
            DEBUG=true
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

if [[ ! $cacheDir = /* ]]; then
    cacheDir="$(pwd)/$cacheDir"
fi

# Capture the first argument as 'script', the rest as 'fileArgs'
shift $((OPTIND-1))
script=$1
shift
fileArgs=("$@")

# create directories
execCacheDir="${cacheDir}/exec";  # results of scripts on inputs
objectCacheDir="${cacheDir}/object";  # content-addressable objects

if [ ! -d "${execCacheDir}" ]; then
    mkdir -p "${execCacheDir}"         
fi

if [ ! -d "${objectCacheDir}" ]; then
    mkdir -p "${objectCacheDir}"
fi

# Makes an entry in the content-addressed cache
# This is actually just a link to the object cache, which contains all unique content. There may be
# many entries in the content cache that point to the same object.
cache() {
    local sourcePath linkPath objectPath
    sourcePath=$1
    linkPath=$2
    objectPath="${objectCacheDir}/$(sha1sum "${sourcePath}" | cut -d' ' -f1)";
    if [[ ! -f "${objectPath}" ]]; then
        mv "${sourcePath}" "${objectPath}"
    fi
    local relativeObjectPath
    relativeObjectPath=$(realpath -s --relative-to="$(dirname "${linkPath}")" "${objectPath}")
    ln -s "${relativeObjectPath}" "${linkPath}"
}

debug "";
debug "========";

fileArgsHash=$(cat "${fileArgs[@]}" | sha1sum | cut -d' ' -f1)
scriptHash=$(sha1sum "${script}" | cut -d' ' -f1)
cachePath="${execCacheDir}/${scriptHash}/${fileArgsHash}"
cachedExitCodePath="${cachePath}/exit"
cachedStdoutPath="${cachePath}/1"
cachedStderrPath="${cachePath}/2"

debug "trying ${script}";

# If we have never run this before, do so and cache the results
if [[ ! -s "${cachedExitCodePath}" ]]; then
    # we have never run this before
    debug "running ${script} on ${fileArgs[*]}";

    mkdir -p "${cachePath}"

    tempStdoutPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
    trap 'rm -f -- "$tempStdoutPath"' EXIT
    tempStderrPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
    trap 'rm -f -- "$tempStderrPath"' EXIT

    debug "writing 1 > ${tempStdoutPath}  2 > ${tempStderrPath}";

    # execute script
    "${script}" "${fileArgs[@]}" > "${tempStdoutPath}" 2>"${tempStderrPath}"
    exitCode=$?

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
else
    echo .... THIS CANNOT WORK BECAUSE WE CAN'T ECHO ORIGINAL SOURCE FILES!!!! we can do many to one but not one to many
fi
if [[ -e $cachedStderrPath ]]; then
    cat "${cachedStderrPath}" >&2
fi
exit "${cachedExitCode}"

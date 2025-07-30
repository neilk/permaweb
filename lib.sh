#!/bin/bash

DEBUG=${DEBUG:+1}  # default false
cacheDirDefault=".cache"

setDebug() {
    DEBUG=0   # true
}

warn() {
    echo "$@" >&2;
}

debug() {
    if [[ "${DEBUG}" ]]; then
        warn "$@"
    fi
}

getDirHash() {
    local dir="$1"
    find "$dir" -type f -print0 | sort -z | xargs -0 sha1sum | sha1sum | cut -d' ' -f1
}

getFileHash() {
    sha1sum "$1" | cut -d' ' -f1
} 

setupCache() {
    cacheDir="${cacheDirDefault}"
    if [[ -n "$1" ]]; then
        cacheDir="$1"
    fi
    execCacheDir="${cacheDir}/exec";  # results of scripts on inputs
    objectCacheDir="${cacheDir}/object";  # content-addressable objects
    mkdir -p "${cacheDir}"         
    mkdir -p "${execCacheDir}"    
    mkdir -p "${objectCacheDir}"
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
        debug "cached object ${objectPath} from ${sourcePath}"
    fi
    local relativeObjectPath
    relativeObjectPath=$(realpath -s --relative-to="$(dirname "${linkPath}")" "${objectPath}")
    ln -sf "${relativeObjectPath}" "${linkPath}"
}

# Get the validator for this extension, if there is one
getValidator() {
    local extension
    extension="$1"
    local validatorsDir
    validatorsDir="$2/validators"
    local validator 
    if [[ -d "$validatorsDir" ]]; then
        validatorPath="${validatorsDir}/${extension}"
        if [[ -f "$validatorPath" && -x "$validatorPath" ]]; then
            validator="$validatorPath"
        fi
    fi
    echo "$validator"
}

executeCached() {
    local itemHash="$1"
    local scriptExec="$2"       
    local contentPath="$3"
    local validator="$4"

    debug "executeCached: itemHash=${itemHash}, scriptExec=${scriptExec}, contentPath=${contentPath}, validator=${validator}"

    fileHash=$(getFileHash "$contentPath")

    # The cache path is a directory containing the exit code, stdout, and stderr.
    local cachePath cachedExitCodePath cachedStdoutPath cachedStderrPath
    cachePath="${execCacheDir}/${fileHash}/${itemHash}"
    cachedExitCodePath="${cachePath}/exit"
    cachedStdoutPath="${cachePath}/1"
    cachedStderrPath="${cachePath}/2"
    
    debug "trying ${scriptExec} (exec: ${scriptExec})";

    # If we have never run this before, do so and cache the results
    if [[ ! -s "${cachedExitCodePath}" ]]; then
        # we have never run this before
        debug "running ${scriptExec} on ${contentPath}";

        mkdir -p "${cachePath}"

        local tempStdoutPath tempStderrPath
        tempStdoutPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
        trap 'rm -f -- "$tempStdoutPath"' EXIT
        tempStderrPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
        trap 'rm -f -- "$tempStderrPath"' EXIT

        debug "writing 1 > ${tempStdoutPath}  2 > ${tempStderrPath}";

        # execute script
        local exitCode
        debug "${scriptExec} < ${contentPath} > ${tempStdoutPath} 2>${tempStderrPath}"
        "${scriptExec}" < "${contentPath}" > "${tempStdoutPath}" 2>"${tempStderrPath}"
        local exitCode=$?

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
    local cachedExitCode
    cachedExitCode=$(<"${cachedExitCodePath}");
    if [[ "${cachedExitCode}" -eq 0 ]]; then
        if [[ -e "${cachedStdoutPath}" ]]; then
            echo "$(dirname "${cachedStdoutPath}")/$(readlink "${cachedStdoutPath}")"
        fi
    fi
    if [[ -e "${cachedStderrPath}" ]]; then
       cat "${cachedStderrPath}" >&2
    fi
    return "${cachedExitCode}"
}
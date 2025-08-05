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



# Function to get a file's extension
get_extension() {
    echo "${1##*.}"
}


# Function to find executables with specific prefixes in a directory
find_executables() {
    local dir="$1"
    local prefix="$2"
    find "$dir" -maxdepth 1 -type f -name "${prefix}*" | sort | while read -r script; do
        if [[ -x "$script" ]]; then
            echo "$script"
        fi
    done
}

# Function to find directory-based executables with specific prefixes
find_dir_executables() {
    local dir="$1"
    local prefix="$2"
    find "$dir" -maxdepth 1 -type d -name "${prefix}*" | sort | while read -r script_dir; do
        if [[ -x "$script_dir/main" || -x "$script_dir/main.sh" ]]; then
            echo "$script_dir"
        fi
    done
}

# Function to determine the right executable for a script dir
get_script_entry() {
    local dir="$1"
    find "$dir" -maxdepth 1 -type f \( -name "main" -o -name "main.*" \) | sort | head -1 | while read -r script; do
        if [[ -x "$script" ]]; then
            echo "$script"
        fi
    done
}



# Process a single file with the map script and return the map result path
# TODO - replace as much as possible with executeCached()
process_file_with_map() {
    local file="$1"
    local mapScript="$2"
    local extension="$3"
    
    local scriptHash scriptExec
    
    # Handle directory-based scripts
    if [[ -d "$mapScript" ]]; then
        scriptHash=$(getDirHash "$mapScript")
        scriptExec=$(get_script_entry "$mapScript")
    else
        scriptHash=$(getFileHash "$mapScript")
        scriptExec="$mapScript"
    fi
    
    debug "Processing $file with map script $mapScript"
    
    # Set environment variable with original file path for script use
    export PERMAWEB_SOURCE_PATH="$file"
    
    # Use executeCached for the caching functionality
    executeCached "$scriptHash" "$scriptExec" "$file" "$validator"
}

# Process all collected map results with the reduce script
# TODO - replace as much as possible with executeCached()
process_with_reduce() {
    local mapResults="$1"
    local reduceScript="$2"
    local extension="$3"
    
    # Create a temporary file listing all map results for environment variable.
    local tempInputsList
    tempInputsList=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
    trap 'rm -f -- "$tempInputsList"' EXIT
    
    for result in $mapResults; do
        echo "$result" >> "$tempInputsList"
    done
    
    # Create hash of all inputs combined with script hash
    local inputsHash scriptHash combinedHash
    inputsHash=$(getFileHash "$tempInputsList")
    
    # Handle directory-based scripts
    local scriptExec
    if [[ -d "$reduceScript" ]]; then
        scriptHash=$(getDirHash "$reduceScript")
        scriptExec=$(get_script_entry "$reduceScript")
    else
        scriptHash=$(getFileHash "$reduceScript")
        scriptExec="$reduceScript"
    fi
    
    # Hash the results as a combination of the inputs and the script 
    combinedHash=$(echo "${inputsHash}${scriptHash}" | sha1sum | cut -d' ' -f1)
    
    debug "Processing $(wc -l < "$tempInputsList") map results with reduce script $reduceScript"
    
    # Check for validator
    local validator=""
    validatorsDir="$reducersDir/validators"
    if [[ -d "$validatorsDir" ]]; then
        validatorPath="${validatorsDir}/${extension}"
        if [[ -f "$validatorPath" && -x "$validatorPath" ]]; then
            validator="$validatorPath"
        fi
    fi
    
    # Export variables for the reduce script
    export PERMAWEB_MAP_RESULTS="$tempInputsList"
    
    # Use executeCached for the caching functionality
    executeCached "$combinedHash" "$scriptExec" "$tempInputsList" "$validator"
}





# Process sce files with map and reduce scripts
performMapReduce() {
    local sourceDir="$1"
    local extension="$2"
    local mapScript="$3"
    local reduceScript="$4"
    local targetPath="$5"
    
    # Process files in the source directory matching the extension
    debug "Finding source files in $sourceDir with extension: <$extension>"
    source_files=$(find "$sourceDir" -type f -name "*.${extension}")
    successful_map_results=""
    
    debug "Found source files: $source_files"
    for file in $source_files; do
        if [[ -n "$mapScript" ]]; then
            debug "Starting to process file: $file with map script: $mapScript"
            if mapResultPath=$(process_file_with_map "$file" "$mapScript" "$extension"); then
                debug "Map successful for $file --> ${mapResultPath}"
                successful_map_results="${successful_map_results} ${mapResultPath}"
            else
                mapExitCode=$?
                debug "Map failed for $file with exit code $mapExitCode"
            fi
        fi
    done

    debug "Collected map results: $successful_map_results"
    
    if [[ -n "$reduceScript" && -n "$successful_map_results" ]]; then
        # Process all collected map results with the reduce script
        if reduceResultPath=$(process_with_reduce "$successful_map_results" "$reduceScript" "$extension"); then
            debug "Reduce successful for $dir"
            # Output the result to the target directory
            cp "$reduceResultPath" "${targetPath}"
            debug "Output written to ${targetPath}"
        else
            reduceExitCode=$?
            warn "Reduce failed for $dir with exit code $reduceExitCode"
        fi
    fi
}



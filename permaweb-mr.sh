#!/bin/bash
# Map-reduce extension to permaweb
# Takes a source directory, runs map scripts on each file, then reduce scripts on the results
# Usage: permaweb-mr.sh [-d] [-s scripts_dir] [-c cache_dir] [-o output_dir] source_dir target_file

set -e

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
outputDir="build"

# parse options
while getopts "ds:c:o:" opt; do
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
        o)
            outputDir="${OPTARG}"
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

if [[ ! $outputDir = /* ]]; then
    outputDir="$(pwd)/$outputDir"
fi

debug "scriptsDir: $scriptsDir  cacheDir: $cacheDir  outputDir: $outputDir"

# create directories
execCacheDir="${cacheDir}/exec"
objectCacheDir="${cacheDir}/object"
mkdir -p "${cacheDir}"
mkdir -p "${execCacheDir}"
mkdir -p "${objectCacheDir}"

# parse positional arguments after options
shift $((OPTIND-1))

# check for source directory and target file
sourceDir="$1"
targetFile="$2"

if [[ -z "${sourceDir}" ]]; then
    warn "No source directory provided"
    exit 1
fi

if [[ ! -d "$sourceDir" ]]; then
    warn "Source directory $sourceDir does not exist"
    exit 1
fi

if [[ -z "${targetFile}" ]]; then
    warn "No target file provided"
    exit 1
fi

# Ensure output directory exists
mkdir -p "$(dirname "${outputDir}/${targetFile}")"

# Function to get a file's extension
get_extension() {
    echo "${1##*.}"
}

# Functions for hashing (reused from permaweb script)
getDirHash() {
    local dir="$1"
    find "$dir" -type f -print0 | sort -z | xargs -0 sha1sum | sha1sum | cut -d' ' -f1
}

getFileHash() {
    sha1sum "$1" | cut -d' ' -f1
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

# Cache function (reused from permaweb script)
cache() {
    local sourcePath linkPath objectPath
    sourcePath=$1
    linkPath=$2
    objectPath="${objectCacheDir}/$(getFileHash "${sourcePath}")";
    if [[ ! -f "${objectPath}" ]]; then
        cp "${sourcePath}" "${objectPath}"
    fi
    local relativeObjectPath
    relativeObjectPath=$(realpath -s --relative-to="$(dirname "${linkPath}")" "${objectPath}")
    ln -sf "${relativeObjectPath}" "${linkPath}"
}

# Process a single file with the map script and return the map result path
process_file_with_map() {
    local file="$1"
    local mapScript="$2"
    local extension="$3"
    
    local fileHash scriptHash cachePath
    fileHash=$(getFileHash "$file")
    
    # Handle directory-based scripts
    if [[ -d "$mapScript" ]]; then
        scriptHash=$(getDirHash "$mapScript")
        scriptExec=$(get_script_entry "$mapScript")
    else
        scriptHash=$(getFileHash "$mapScript")
        scriptExec="$mapScript"
    fi
    
    # Cache path for this file+map combination
    cachePath="${cacheDir}/${fileHash}/${scriptHash}"
    cachedExitCodePath="${cachePath}/exit"
    cachedStdoutPath="${cachePath}/1"
    cachedStderrPath="${cachePath}/2"
    
    debug "Processing $file with map script $mapScript"
    
    # If not already cached, run the map script
    if [[ ! -s "${cachedExitCodePath}" ]]; then
        debug "Running map script $scriptExec on $file"
        
        mkdir -p "${cachePath}"
        
        local tempStdoutPath tempStderrPath
        tempStdoutPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
        trap 'rm -f -- "$tempStdoutPath"' EXIT
        tempStderrPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
        trap 'rm -f -- "$tempStderrPath"' EXIT
        
        # Set environment variable with original file path for script use
        export PERMAWEB_SOURCE_PATH="$file"
        
        # Execute the map script
        debug "${scriptExec} exists? $(command -v "${scriptExec}")"
        debug "Running ${scriptExec} < $file > ${tempStdoutPath} 2>${tempStderrPath}"
        "${scriptExec}" < "$file" > "${tempStdoutPath}" 2>"${tempStderrPath}"
        local exitCode=$?
        
        # Check for validator
        local validator=""
        validatorsDir="$scriptsDir/validators"
        if [[ -d "$validatorsDir" ]]; then
            validatorPath="${validatorsDir}/${extension}"
            if [[ -f "$validatorPath" && -x "$validatorPath" ]]; then
                validator="$validatorPath"
                debug "Running validator ${validator}"
                "${validator}" < "${tempStdoutPath}" 1>&2 2>>"${tempStderrPath}"
                exitCode=$?
            fi
        fi
        
        echo "${exitCode}" > "${cachedExitCodePath}"
        cache "${tempStdoutPath}" "${cachedStdoutPath}"
        cache "${tempStderrPath}" "${cachedStderrPath}"
    fi
    
    # Return the cached result path if successful
    local cachedExitCode
    cachedExitCode=$(<"${cachedExitCodePath}")
    
    if [[ -e "${cachedStderrPath}" ]]; then
        cat "${cachedStderrPath}" >&2
    fi
    
    if [[ "${cachedExitCode}" -eq 0 && -e "${cachedStdoutPath}" ]]; then
        echo "$(dirname "${cachedStdoutPath}")/$(readlink "${cachedStdoutPath}")"
        return 0
    else
        return "${cachedExitCode}"
    fi
}

# Process all collected map results with the reduce script
process_with_reduce() {
    local mapResults="$1"
    local reduceScript="$2"
    local extension="$3"
    
    # Create a hash of all inputs (file paths and their modification times)
    local inputsHash tempInputsList
    tempInputsList=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
    trap 'rm -f -- "$tempInputsList"' EXIT
    
    for result in $mapResults; do
        echo "$result" >> "$tempInputsList"
    done
    
    inputsHash=$(getFileHash "$tempInputsList")
    
    # Handle directory-based scripts
    local scriptHash scriptExec
    if [[ -d "$reduceScript" ]]; then
        scriptHash=$(getDirHash "$reduceScript")
        scriptExec=$(get_script_entry "$reduceScript")
    else
        scriptHash=$(getFileHash "$reduceScript")
        scriptExec="$reduceScript"
    fi
    
    # Cache path for this reduce operation
    local cachePath="${cacheDir}/${inputsHash}/${scriptHash}"
    local cachedExitCodePath="${cachePath}/exit"
    local cachedStdoutPath="${cachePath}/1"
    local cachedStderrPath="${cachePath}/2"
    
    debug "Processing $(wc -l < "$tempInputsList") map results with reduce script $reduceScript"
    
    # If not already cached, run the reduce script
    if [[ ! -s "${cachedExitCodePath}" ]]; then
        debug "Running reduce script $scriptExec"
        
        mkdir -p "${cachePath}"
        
        local tempStdoutPath tempStderrPath
        tempStdoutPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
        trap 'rm -f -- "$tempStdoutPath"' EXIT
        tempStderrPath=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
        trap 'rm -f -- "$tempStderrPath"' EXIT
        
        # Create a temporary file with all map results for the reduce script to read
        local tempMapResultsFile
        tempMapResultsFile=$(mktemp -q "/tmp/permaweb.XXXXX" || exit 1)
        trap 'rm -f -- "$tempMapResultsFile"' EXIT
        
        for result in $mapResults; do
            cat "$result" >> "$tempMapResultsFile"
        done
        
        # Export variables
        export PERMAWEB_SOURCE_DIR="$sourceDir"
        export PERMAWEB_MAP_RESULTS="$tempInputsList"
        
        # Execute the reduce script
        "${scriptExec}" < "$tempMapResultsFile" > "${tempStdoutPath}" 2>"${tempStderrPath}"
        local exitCode=$?
        
        # Check for validator
        local validator=""
        validatorsDir="$scriptsDir/validators"
        if [[ -d "$validatorsDir" ]]; then
            validatorPath="${validatorsDir}/${extension}"
            if [[ -f "$validatorPath" && -x "$validatorPath" ]]; then
                validator="$validatorPath"
                debug "Running validator ${validator}"
                "${validator}" < "${tempStdoutPath}" 1>&2 2>>"${tempStderrPath}"
                exitCode=$?
            fi
        fi
        
        echo "${exitCode}" > "${cachedExitCodePath}"
        cache "${tempStdoutPath}" "${cachedStdoutPath}"
        cache "${tempStderrPath}" "${cachedStderrPath}"
        
        rm -f "$tempMapResultsFile"
    fi
    
    # Return the cached result path if successful
    local cachedExitCode
    cachedExitCode=$(<"${cachedExitCodePath}")
    
    if [[ -e "${cachedStderrPath}" ]]; then
        cat "${cachedStderrPath}" >&2
    fi
    
    if [[ "${cachedExitCode}" -eq 0 && -e "${cachedStdoutPath}" ]]; then
        echo "$(dirname "${cachedStdoutPath}")/$(readlink "${cachedStdoutPath}")"
        return 0
    else
        return "${cachedExitCode}"
    fi
}

# Main logic for map-reduce processing

# Extract extension from target file to determine which scripts to run
extension=$(get_extension "$targetFile")
debug "Target file extension: $extension"

# Check for map-reduce scripts directory
mapReduceDir="${scriptsDir}/map-reduce"
if [[ ! -d "${mapReduceDir}" ]]; then
    warn "No map-reduce directory found at ${mapReduceDir}"
    exit 1
fi

formatDir="${mapReduceDir}/${extension}"
if [[ ! -d "${formatDir}" ]]; then
    warn "No map-reduce scripts found for ${extension} format"
    exit 1
fi

# Find map script for this format


function getMapOrReduceScript() {
    local formatDir="$1"
    local scriptType="$2"
    local script;
    if [[ -d "${formatDir}/${scriptType}" ]]; then 
        script="${formatDir}/${scriptType}"
    else
        script=$(find $formatDir -maxdepth 1 -type f \( -name "$scriptType" -o -name "$scriptType.*" \) -perm -u=x | head -1)
    fi
    if [[ -z "$script" ]]; then
        warn "No ${scriptType} scripts found!"
        exit 1
    fi
    echo "$script"
}

mapScript=$(getMapOrReduceScript "$formatDir" "map")
reduceScript=$(getMapOrReduceScript "$formatDir" "reduce")

debug "Using map script: <$mapScript>"
debug "Using reduce script: <$reduceScript>"

# Process each file in the source directory that matches the target extension
successful_map_results=""
source_files=$(find "$sourceDir" -type f -name "*.${extension}")

for file in $source_files; do
    mapResultPath=$(process_file_with_map "$file" "$mapScript" "$extension")
    mapExitCode=$?
    
    if [[ $mapExitCode -eq 0 ]]; then
        debug "Map successful for $file"
        successful_map_results="${successful_map_results} ${mapResultPath}"
    else
        debug "Map failed for $file with exit code $mapExitCode"
    fi
done

debug "Successful map results: $successful_map_results"
if [[ -z "$successful_map_results" ]]; then
    warn "No successful map results to reduce"
    exit 1
fi

# Process all collected map results with the reduce script
reduceResultPath=$(process_with_reduce "$successful_map_results" "$reduceScript" "$extension")
reduceExitCode=$?

if [[ $reduceExitCode -eq 0 ]]; then
    debug "Reduce successful"
    # Output the result to the target file
    mkdir -p "$(dirname "${outputDir}/${targetFile}")"
    cat "$reduceResultPath" > "${outputDir}/${targetFile}"
    debug "Output written to ${outputDir}/${targetFile}"
else
    warn "Reduce failed with exit code $reduceExitCode"
    exit $reduceExitCode
fi
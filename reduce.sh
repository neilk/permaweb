#!/bin/bash
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/_reduce.sh"

# Map-reduce extension to permaweb
# Takes a source directory, runs map scripts on each file, then reduce scripts on the results
# Usage: permaweb-mr.sh [-d] [-s scripts_dir] [-c cache_dir] [-o output_dir] source_dir target_file

set -e

# defaults
reducersDir="reducers"
cacheDir=".cache"
outputDir="build"

# parse options
while getopts "ds:c:o:" opt; do
    case "${opt}" in
        d)
            setDebug;
            ;;
        s)
            reducersDir="${OPTARG}"
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
if [[ ! $reducersDir = /* ]]; then
    reducersDir="$(pwd)/$reducersDir"
fi

if [[ ! $cacheDir = /* ]]; then
    cacheDir="$(pwd)/$cacheDir"
fi

if [[ ! $outputDir = /* ]]; then
    outputDir="$(pwd)/$outputDir"
fi

# parse positional arguments after options
shift $((OPTIND-1))

# check for source directory and target file
sourceDir="$1"

debug "sourceDir: $sourceDir reducersDir: $reducersDir  cacheDir: $cacheDir  outputDir: $outputDir"

setupCache "$cacheDir";


if [[ -z "${sourceDir}" ]]; then
    warn "No source directory provided"
    exit 1
fi

if [[ ! -d "$sourceDir" ]]; then
    warn "Source directory $sourceDir does not exist"
    exit 1
fi

# Child scripts may need to know the source directory to analyze "sibling" files so export it
export PERMAWEB_SOURCE_DIR="$sourceDir"


if [[ -z "${outputDir}" ]]; then
    warn "No target directory provided"
    exit 1
fi



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



function getMapOrReduceScript() {
    local formatDir="$1"
    local scriptType="$2"
    local script;
    if [[ -d "${formatDir}/${scriptType}" ]]; then 
        script="${formatDir}/${scriptType}"
    else
        script=$(find $formatDir -maxdepth 1 -type f \( -name "$scriptType" -o -name "$scriptType.*" \) -perm -u=x | head -1)
    fi
    echo "$script"
}

function reduceDir() {
    local dir="$1"
    debug "Checking directory: $dir"
    # Check if the directory contains "map", "map.*", "reduce", or "reduce.*"
    local mapScript
    mapScript=$(getMapOrReduceScript "$dir" "map")
    local reduceScript
    reduceScript=$(getMapOrReduceScript "$dir" "reduce")
    
    if [[ -n "$mapScript" && -n "$reduceScript" ]]; then
        debug "Found map and reduce scripts in $dir"
        debug "Using map script: <$mapScript>"
        debug "Using reduce script: <$reduceScript>"        
        # Determine the target directory path rebased to the outputDir
        relativePath=$(realpath --relative-to="${reducersDir}/${extension}" "$dir")
        targetPath="${outputDir}/${relativePath}"
        debug "Target path: $targetPath"
        # Ensure the target directory exists
        mkdir -p "$(dirname "$targetPath")"
        
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
    fi
}

# Given a directory structure like this:
# reducers/
#   html/
#     feeds/
#       index.rss/
#         map.js
#         reduce.sh
#      sitemap.xml/
#         map/
#           main.py
#         reduce.py
# 
# 1) Depth first search through the reducersDir to find anything with an appropriate map and reduce script.
# 2) For each directory with a map and reduce script, use that as the targetFile for the whole process, e.g. feeds/index.rss
# 3) get the (possibly-already cached) result of passing every html file through the map script
# 3) get the (possibly-already cached) result of passing the map results through the reduce script
# 4) Write the final result to the $outputDir/feeds/index.rss
# 5) repeat the above with /sitemap.xml
reduce() {
    local reducerDir
    reducerDir="$1"
    local extension
    extension=$(basename "$1")
    debug "Processing reducers for: $extension"
    # Perform a depth-first search through "${reducersDir}/${extension}"

    find "$reducerDir" -type d | while read -r dir; do
        reduceDir "$dir"
    done
    
}

# The first level of the reducers directory contains the extensions we will be processing.
for reducersFile in "${reducersDir}"/*/; do
    if [[ -d "$reducersFile" ]]; then
        extension=$(basename "$reducersFile")
        debug "Found reducers directory for extension: $extension"
        reduce "${reducersDir}/${extension}"
    fi
done


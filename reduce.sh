#!/bin/bash
. "$(dirname "$0")/lib.sh"

# Run all the map-reduce scripts. This responsibility may be taken over by the Makefile in the future.

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

# Check if this directory could be a map-reduce directory. It could have a "map" or "reduce" script,
# a "map.*" or "reduce.*" script in it, or a "map" or "reduce" directory in it.
function getMapOrReduceScript() {
    local dir="$1"
    local scriptType="$2"
    local script;
    if [[ -d "${dir}/${scriptType}" ]]; then 
        script="${dir}/${scriptType}"
    else
        script=$(find $dir -maxdepth 1 -type f \( -name "$scriptType" -o -name "$scriptType.*" \) -perm -u=x | head -1)
    fi
    echo "$script"
}

# The convention for "reducers" directory looks like this. Here we express that we want to create the file 
#  $BUILD/feeds/index.rss by running the map and reduce scripts in the feeds/index.rss directory. And then we want 
#  to create $BUILD/sitemap.xml in a similar way. Finally, for some reason, we are going to count every jpg file in the 
#  source directory and write that to $BUILD/jpg/count.txt.
# 
# reducers/
#   html/
#     feeds/
#       index.rss/
#         map.js
#         reduce.sh
#     sitemap.xml/
#         map/
#           main.py
#         reduce.py
#   jpg/
#     count.txt/
#       map.py
#       reduce.py
reduce() {
    local extensionDir
    extensionDir="$1"

    debug "Processing reducers for: $extensionDir"

    # Perform a depth-first search. If any directory looks like it 
    # can do map-reduce then run it there, with the target file defined by the directory path.
    find "$extensionDir" -type d | while read -r dir; do
        debug "Checking directory: $dir"
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
            
            performMapReduce "$sourceDir" "$extension" "$mapScript" "$reduceScript" "$targetPath"
        fi
    done
}

# The first level of the reducers directory contains the extensions we will be processing.
for extensionDir in "${reducersDir}"/*/; do
    if [[ -d "$extensionDir" ]]; then
        extension=$(basename "$extensionDir")
        debug "Found reducers directory for extension: $extension"
        reduce "${reducersDir}/${extension}"
    fi
done


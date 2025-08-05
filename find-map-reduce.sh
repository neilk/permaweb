#!/bin/bash

# Script to find map-reduce directories and extract their components
# Outputs pipe-delimited format: reducer_dir|extension|relative_target|map_script|reduce_script

set -e

# defaults
reducersDir="reducers"

# parse options
while getopts "r:" opt; do
    case "${opt}" in
        r)
            reducersDir="${OPTARG}"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

# Function to find map or reduce script in a directory (matches logic from lib.sh)
getMapOrReduceScript() {
    local dir="$1"
    local scriptType="$2"
    local script;
    if [[ -d "${dir}/${scriptType}" ]]; then 
        script="${dir}/${scriptType}"
    else
        script=$(find "$dir" -maxdepth 1 -type f \( -name "$scriptType" -o -name "$scriptType.*" \) -perm -u=x | head -1)
    fi
    echo "$script"
}

# Find all reducer directories and extract their components
find "$reducersDir" -type d 2>/dev/null | while read -r dir; do
    # Extract extension (second path component)
    extension=$(echo "$dir" | cut -d'/' -f2)
    
    # Generate relative target path (remove reducers/extension/ prefix)
    relative_target="${dir#"$reducersDir"/*/}"
    
    # Find map script
    map_script=$(getMapOrReduceScript "$dir" "map")
    
    # Find reduce script  
    reduce_script=$(getMapOrReduceScript "$dir" "reduce")
    
    # Only output if both map and reduce scripts exist
    if [[ -n "$map_script" && -n "$reduce_script" ]]; then
        echo "$dir|$extension|$relative_target|$map_script|$reduce_script"
    fi
done
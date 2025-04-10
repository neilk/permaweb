#!/bin/bash

# Debug the script discovery process
scripts_dir="./scripts/html"
echo "Checking directory: $scripts_dir"

if [ -d "$scripts_dir" ]; then
    echo "Directory exists"
    
    # Test findScriptEntry function
    find_script_entry() {
        local dir="$1"
        echo "Finding entry point in: $dir"
        find "$dir" -maxdepth 1 -type f -perm -u=x \( -name "main" -o -name "main.*" \) | head -1
    }
    
    # Test isScriptDir function
    is_script_dir() {
        local path="$1"
        local entry=""
        
        if [ -d "$path" ]; then
            echo "Path is a directory: $path"
            entry=$(find_script_entry "$path")
            if [ -n "$entry" ] && [ -x "$entry" ]; then
                echo "Found executable entry: $entry"
                return 0
            else
                echo "No executable entry found"
                return 1
            fi
        fi
        echo "Not a directory: $path"
        return 1
    }
    
    echo "Finding all items in script directory:"
    while IFS= read -r -d $'\0' script; do
        echo "Found: $script"
        if [ -f "$script" ] && [ -x "$script" ]; then
            echo "  - Regular executable file"
        elif is_script_dir "$script"; then
            echo "  - Script directory with entry point"
        else
            echo "  - Not recognized as script or directory with entry point"
        fi
    done < <(find "$scripts_dir" -mindepth 1 -maxdepth 1 -not -path "*/\.*" -print0 | sort -z)
else
    echo "Directory does not exist: $scripts_dir"
fi
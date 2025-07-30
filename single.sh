#!/bin/bash
. "$(dirname "$0")/lib.sh"
# set -E
#
#handle_error() {
#    local retval=$?
#    local line=$1
#    echo "Failed at $line: $BASH_COMMAND"
#    exit $retval
#}
#trap 'handle_error $LINENO' ERR


# defaults
scriptsDir="scripts"
cacheDir=".cache"

# parse options
while getopts "ds:c:" opt; do
    case "${opt}" in
        d)
            setDebug
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

setupCache "$cacheDir";

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

# Find the executable entry point in a script directory
# Convention: use 'main' or 'main.*' as the entry point
findScriptEntry() {
    find "$1" -maxdepth 1 -type f \( -name "main" -o -name "main.*" \) -perm -u=x | head -1
}

# Function to determine if script is directory-based with an executable entry point
isScriptDir() {
    local path="$1"
    local entry=""
    
    if [[ -d "$path" ]]; then
        entry=$(findScriptEntry "$path")
        [[ -n "$entry" && -x "$entry" ]]
        return $?
    fi
    return 1
}

# Get script executable path (either script file or entry point in directory)
getScriptExec() {
    local script="$1"
    if isScriptDir "$script"; then
        findScriptEntry "$script"
    else
        echo "$script"
    fi
}

getItemHash() {
    local item="$1"
    if isScriptDir "$item"; then
        getDirHash "$item"
    else
        getFileHash "$item"
    fi
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

    local contentPath script scriptExec
    contentPath="$1"
    script="$2"
    scriptExec=$(getScriptExec "$script")

    # itemHash is the hash of everything that is part of processing:
    #  the hash of the script file and any ancillary files it uses 
    # TODO: push the determination of the "itemHash" downwards somehow. 
    # We can't right now because map-reduce has different directory conventions. Perhaps 
    # we can instead push the list of files downwards.
    itemHash=$(getItemHash "$script")

    executeCached "$itemHash" "$scriptExec" "$contentPath" "$validator"
}


# Because this script transforms input files into the same kind of file, 
# there is a common validator for every script run in the pipeline.
validator=$(getValidator "$extension" "$scriptsDir")
debug "(((( $extension $scriptsDir validator: $validator ))))";

# Build the array of scripts
scripts=();
if [[ -n "${extension}" ]]; then
    if [[ -d "${scriptsDir}/${extension}" ]]; then        
        # The first "script" is a no-op, cat, because we need to validate the file as is.
        scripts=('/bin/cat');
        while IFS=  read -r -d $'\0' script; do
            # Accept both executable files and directories containing main.* or main
            if [[ -f "$script" && -x "$script" ]] || isScriptDir "$script"; then
                scripts+=("$script")
            fi
        done < <(find "${scriptsDir}/${extension}" -mindepth 1 -maxdepth 1 -print0 | sort -z)
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
        warn "${PERMAWEB_SOURCE_PATH}: Script ${script} failed or failed to validate; skipping";
        continue;
    fi
    # Somehow, this has occurred that we get success on the script but no output path. This indicates a bug in our processing, probably,
    # but we guard against it anyway.
    if [[ -z "${newContentPath}" ]]; then
        warn "Script ${script} < "${contentPath}" did not produce a path";
        continue;
    fi
    if [[ ! -f "${newContentPath}" ]]; then
        warn "Script ${script} < "${contentPath}" was supposed to produce a file: ${newContentPath} does not exist";
        continue;
    fi

    debug "new input path is ${newContentPath}";
    contentPath="${newContentPath}";
done

# Print the successful results of the transformations
debug "input path is ${contentPath}"
cat "$contentPath";
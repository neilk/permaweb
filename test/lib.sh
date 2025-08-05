#!/bin/bash
    
# Find the project root (where find-map-reduce.sh is located)
PROJECT_ROOT="$(realpath "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..")"

warn() {
    echo "$@" >&2;
}

handle_error() {
    local retval=$?
    local line=$1
    echo "Failed at $line: $BASH_COMMAND"
    exit $retval
}

debug() {
    if [[ "${DEBUG}" ]]; then
        warn "$@"
    fi
}

# params: Message, Assertion
assert() {                         
  E_PARAM_ERR=98
  E_ASSERT_FAILED=99

  if [ -z "$2" ] 
  then                   
    return $E_PARAM_ERR   
  fi

  message=$1
  assertion=$2

  if ! eval "[ $assertion ]" 
  then
    warn "𐄂 $message"
    exit $E_ASSERT_FAILED
  else
    warn "✓ $message"
    return
  fi  
} 

# given a file, get the hash
getFileHash() {
    sha1sum "$1" | cut -d' ' -f1
}

# Generate random alphanumeric string
# Usage: generate_random_string [length]
generate_random_string() {
    local length=${1:-8}
    LC_CTYPE=C tr -dc '[:alnum:]' < /dev/random | dd bs="$length" count=1 2>/dev/null
}


# Common tests
assert_cache_ok() {
    cacheDir="$1"

    # assert the .engine directories exist
    assert "cache directory exists" "-d $cacheDir"
    assert "exec directory exists" "-d $cacheDir/exec"
    assert "object directory exists"  "-d $cacheDir/object"

    # Every file in 'object' is named according to its sha1 hash
    # for file in ./engine/object
    for file in "$cacheDir"/object/*; do
        [ -e "$file" ] || continue   # directory was empty and bash is stupid, gives us the glob pattern.
        hash=$(getFileHash "$file")
        bn=$(basename "$file")
        assert "object basename matches its content" "$hash == $bn"
    done;

    # Every subdirectory in cache has the structure of 1 -> link, 2 -> link, exit -> file
    for dir in "$cacheDir"/exec/*; do
        [ -d "$dir" ] || continue
        assert "exec contains directory" "-d $dir"
        for subdir in "$dir"/*; do
            [ -d "$subdir" ] || continue
            assert "directory contains link at 1" "-L $subdir/1"
            assert "directory contains link at 2" "-L $subdir/2"
            assert "directory contains file at exit" "-f $subdir/exit"
        done;
    done;
}

# Function to test map-reduce directory discovery
# Usage: find_mapreduce_rules
find_mapreduce_rules() {
    local reducersDir
    reducersDir="$1"
    "$PROJECT_ROOT/find-map-reduce.sh" -r "$reducersDir"
}

# Function to parse map-reduce rule output
# Usage: parse_mapreduce_rule "rule_line" variable_name
# Sets variables: RULE_DIR, RULE_EXTENSION, RULE_TARGET, RULE_MAP_SCRIPT, RULE_REDUCE_SCRIPT
parse_mapreduce_rule() {
    local rule_line="$1"
    
    export RULE_DIR RULE_EXTENSION RULE_TARGET RULE_MAP_SCRIPT RULE_REDUCE_SCRIPT

    IFS='|' read -r RULE_DIR RULE_EXTENSION RULE_TARGET RULE_MAP_SCRIPT RULE_REDUCE_SCRIPT <<< "$rule_line"
}

# Function to run both map-reduce operations
doMapReduce() {
    local sourceDir;
    sourceDir="$1"
    local cacheDir;
    cacheDir="$2"
    local reducersDir;
    reducersDir="$3"
    local outputDir;
    outputDir="$4"
    
    # Get all map-reduce rules
    rules_output=$(find_mapreduce_rules "$reducersDir")
    if [[ -z "$rules_output" ]]; then
        warn "No map-reduce rules found in $reducersDir"
        return 1
    fi
    
    # Process each rule
    while IFS= read -r rule_line; do
        [[ -n "$rule_line" ]] || continue
        
        parse_mapreduce_rule "$rule_line"
        
        target_file="$outputDir/$RULE_TARGET"
        mkdir -p "$(dirname "$target_file")"

        "$PROJECT_ROOT/reduce-target.sh" -c "$cacheDir" -s "$sourceDir" -e "$RULE_EXTENSION" -m "$RULE_MAP_SCRIPT" -r "$RULE_REDUCE_SCRIPT" -t "$target_file"
    done <<< "$rules_output"
}

# Function to test that map-reduce discovery works correctly
# Usage: test_mapreduce_discovery expected_count
test_mapreduce_discovery() {
    local expected_count="$1"
    local reducersDir=${2:-"reducers"}
    local rules_output
    local actual_count
    
    rules_output=$(find_mapreduce_rules "$reducersDir")
    actual_count=$(echo "$rules_output" | wc -l)

    debug "Discovered map-reduce rules:"
    debug "$rules_output"
    
    if [[ -z "$rules_output" ]]; then
        actual_count=0
    fi
    
    assert "Found expected number of map-reduce rules" "$actual_count == $expected_count"
    
    # Return the rules for further testing
    echo "$rules_output"
}
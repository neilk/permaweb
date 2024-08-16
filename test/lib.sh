#!/bin/bash

warn() {
    echo "$@" >&2;
}

handle_error() {
    local retval=$?
    local line=$1
    echo "Failed at $line: $BASH_COMMAND"
    exit $retval
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

  # shellcheck disable=SC2086
  if [ ! $assertion ] 
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


# Common tests
assert_cache_ok() {
    cacheDir="$1"

    # assert the .engine directories exist
    assert "cache directory exists" "-d $cacheDir"
    assert "exec directory exists" "-d $cacheDir/exec"
    assert "object directory exists"  "-d $cacheDir//object"

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
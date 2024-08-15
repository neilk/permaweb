PERMAWEB

requires gmake and other coreutils

to make the build dir, 

gmake clean && gmake

to upload, use rsync, as in 

cd build
rsync -av --delete . brevity@brevity.org:neilk.net




# Testing





```
# This is conceptually what we are doing, but because of the cache we never actually used this?

# If command succeeds, return output
# If command fails, return input
pipeOrPass() {
    local tmp_input tmp_output
    
    tmp_input=$(mktemp)
    tmp_output=$(mktemp)
    
    trap 'rm -f "$tmp_input" "$tmp_output"' EXIT

    cat > "$tmp_input"
    
    if "$@" < "$tmp_input" > "$tmp_output"; then
        cat "$tmp_output"
    else
        cat "$tmp_input"
    fi
}
```


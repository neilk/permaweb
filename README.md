PERMAWEB

requires gmake and other coreutils

to make the build dir, 

gmake clean && gmake

to upload, use rsync, as in 

cd build
rsync -av --delete . brevity@brevity.org:neilk.net



# Next test - ensure the caching works

create a temp file
write scripts that cat to the temp file
grep the temp file to see which scripts executed

run the entire thing again, with the _same_ cached directory and script directory
and see what ran

run the entire thing again with the same cached directory and a similar, but not identical, script directory
and see what ran



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



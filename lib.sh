#!/bin/bash

warn() {
    echo "$@" >&2;
}

debug() {
    if "${DEBUG}"; then
        warn "$@"
    fi
}

getDirHash() {
    local dir="$1"
    find "$dir" -type f -print0 | sort -z | xargs -0 sha1sum | sha1sum | cut -d' ' -f1
}

getFileHash() {
    sha1sum "$1" | cut -d' ' -f1
} 
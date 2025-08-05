#!/bin/bash
. "$(dirname "$0")/lib.sh"

# Run all the map-reduce scripts. This responsibility may be taken over by the Makefile in the future.

set -e

# defaults
export cacheDir=".cache"

# parse options
while getopts "ds:e:m:r:t:c:" opt; do
    case "${opt}" in
        d)
            setDebug;
            ;;
        s)
            sourceDir="${OPTARG}"
            ;;
        e) 
            extension="${OPTARG}"
            ;;
        m)
            mapScript="${OPTARG}"
            ;;
        r)
            reduceScript="${OPTARG}"
            ;;
        t)
            targetPath="${OPTARG}"
            ;;
        c)
            cacheDir="${OPTARG}"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

# Allow specified paths to be relative
if [[ ! $sourceDir = /* ]]; then
    sourceDir="$(pwd)/$sourceDir"
fi

if [[ ! $cacheDir = /* ]]; then
    cacheDir="$(pwd)/$cacheDir"
fi

if [[ ! $mapScript = /* ]]; then
    mapScript="$(pwd)/$mapScript"
fi

if [[ ! $reduceScript = /* ]]; then
    reduceScript="$(pwd)/$reduceScript"
fi

if [[ ! $targetPath = /* ]]; then
    targetPath="$(pwd)/$targetPath"
fi

setupCache "$cacheDir";

if [[ -z "${sourceDir}" ]]; then
    warn "No source directory provided"
    exit 1
fi
if [[ ! -d "$sourceDir" ]]; then
    warn "Source directory $sourceDir does not exist"
    exit 1
fi
if [[ -z "${extension}" ]]; then
    warn "No extension provided"
    exit 1
fi
if [[ -z "${mapScript}" ]]; then
    warn "No map script provided"
    exit 1
fi
if [[ -z "${reduceScript}" ]]; then
    warn "No reduce script provided"
    exit 1
fi
if [[ -z "${targetPath}" ]]; then
    warn "No target path provided"
    exit 1
fi

performMapReduce "$sourceDir" "$extension" "$mapScript" "$reduceScript" "$targetPath"
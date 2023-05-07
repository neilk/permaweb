#!/bin/bash

while read -r sourceFile; do
    targetFile=$(echo "$sourceFile" | sed -e 's/^source/build/');
    
    mkdir -p "$(dirname "$targetFile")";

    echo "engine.sh $sourceFile > $targetFile";
    ./engine.sh "$sourceFile" > "$targetFile";
done < <(find source -type f)

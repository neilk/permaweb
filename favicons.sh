#!/bin/sh

SOURCE=$1
SIZE=$2 

magick "$SOURCE" \
     -resize "${SIZE}x${SIZE}\!" \
     -
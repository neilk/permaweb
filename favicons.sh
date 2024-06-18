#!/bin/sh

SOURCE=$1
SIZE=$2 

# From https://stackoverflow.com/questions/47112067/how-do-i-circle-select-and-crop-with-fu-script
# I changed 0 to 1 because otherwise the radius exceeded the image size by 1 pixel
magick "$SOURCE" \
    \( \
        +clone \
        -fill black \
        -colorize 100% \
        -fill white \
        -draw "circle %[fx:int(w/2)],%[fx:int(h/2)] %[fx:w>h?int(w/2):1],%[fx:w>h?1:int(h/2)]" \
        -alpha off \
     \) \
     -compose copyopacity \
     -composite \
     -trim +repage \
     -resize "${SIZE}x${SIZE}\!" \
     -
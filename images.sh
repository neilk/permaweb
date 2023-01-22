#!/bin/sh

SOURCE=./neilk-avatar.png
TARGET_DIR=site/images


source_basename=$(basename -- "$SOURCE")
source_name="${source_basename%.*}"


cp "$SOURCE" "${TARGET_DIR}/${source_basename}"

circle_image=$(mktemp)   # "${TARGET_DIR}/${source_name}-circle.png"


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
     -trim +repage "$circle_image"

for size in 16 32 96; do
    target_icon_filename="site/icons/favicon-${size}.png"
    magick "$circle_image" -resize "${size}x${size}\!" "$target_icon_filename"
done;
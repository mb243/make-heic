#!/usr/bin/env bash

# - Ensure tools are available
for e in "convert" "exiftool" "bc"; do
    if ! [ -x "$(command -v $e)" ]; then
    echo "Error: $e is not installed." >&2
    exit 1
    fi
done

# - Convert all jpeg files in the current directory to heic
# Print file size reduction for good feels
for x in *.jpeg; do
    y="${x%jpeg}heic"
    echo -n "converting $x ... "
    convert "$x" "$y"
    sizeOld=$(stat -f "%z" "$x")
    sizeNew=$(stat -f "%z" "$y")
    perc=$(bc <<< "scale=2; ($sizeNew - $sizeOld)/$sizeOld * 100")
    echo "new file size: $perc %"
done   

# - Merge in any metadata provided in xmp files that exiftool can handle
# Preserve the data location at the same time. 
# More info: https://exiftool.org/faq.html#Q9
for x in *.heic; do
    y="${x%heic}xmp"
    echo "merging exifdata for $x ..."
    exiftool -overwrite_original -tagsFromFile "$y" -all:all "$x"
done

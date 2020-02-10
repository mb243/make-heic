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
for hfile in *.heic; do
    xfile="${hfile%heic}xmp"
    echo "$xfile XMP data to $hfile ..."
    exiftool -overwrite_original -tagsFromFile "$xfile" -all:all "$hfile"
    # hacky workaround for GPS coordinates not being accurate
    # requires ggrep or grep with -P for perl regex matching
    echo "  Recalculating GPS coords for $hfile ..."
    GPSLatitude=$(ggrep -P "(?<=<exif:GPSLatitude>)[0-9.]*" -o "$xfile")
    GPSLatitudeRef=$(ggrep -P "(?<=<exif:GPSLatitudeRef>)[A-Z]" -o "$xfile")
    GPSLongitude=$(ggrep -P "(?<=<exif:GPSLongitude>)[0-9.]*" -o "$xfile")
    GPSLongitudeRef=$(ggrep -P "(?<=<exif:GPSLongitudeRef>)[A-Z]" -o "$xfile")
    echo "  Found Lat = ${GPSLatitude}${GPSLatitudeRef} Long = ${GPSLongitude}${GPSLongitudeRef}"
    exiftool \
        -m -overwrite_original \
        -GPS:GPSLatitude="${GPSLatitude}" \
        -GPS:GPSLatitudeRef=${GPSLatitudeRef} \
        -GPS:GPSLongitude="${GPSLongitude}" \
        -GPS:GPSLongitudeRef=${GPSLongitudeRef} \
        "$hfile"
done

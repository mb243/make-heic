#!/usr/bin/env bash
set -euo pipefail  # Always use protection

# NOT RECOMMENDED: If you want any convert options applied, specify them here.
# Provided options will be applied to EVERY image converted.
# See https://imagemagick.org/script/convert.php
convert_options=""

check_requirements() {
    # Ensure tools are available
    # brew install imagemagick
    for tool in convert exiftool bc ggrep; do
        if [ ! -x "$(command -v $tool)" ]; then
        echo "Error: '$tool' is not installed or available in PATH." # >&2
        exit 1
        fi
    done
}

assure_file_readable() {
    if [ ! -r "$1" ]; then
        echo "$1 does not exist or is not readable. Bailing."
        exit 1
    fi
}

convert_jpeg_to_heic() {
    # Convert the given file from jpeg to heic
    j_file="$1"
    h_file="$2"
    echo "Converting $j_file to $h_file ..."
    convert "$j_file" $convert_options "$h_file" 

    # Print file size reduction for good feels
    sizeOld=$(stat -f "%z" "$j_file")
    sizeNew=$(stat -f "%z" "$h_file")
    perc=$(bc <<< "scale=2; ($sizeNew - $sizeOld)/$sizeOld * 100")
    echo "  old file size: $sizeOld; new file size: $sizeNew ($perc %)"
}

import_xmp_to_heic() {
    # - Merge in any metadata provided in xmp files that exiftool can handle
    # Parameters:
    # $1 = name of xmp file
    # $2 = name of heic file

    # Check to make sure both files exist and are readable
    assure_file_readable "$1"
    assure_file_readable "$2"
    echo "  Importing XMP data from $1 to $2 ..."
    exiftool -overwrite_original -tagsFromFile "$1" -all:all "$2"
}

import_fixed_xmp_gps_to_heic() {
    # hacky workaround for GPS coordinates not being accurate when imported from exiftool
    # requires ggrep or grep with -P for perl regex matching

    # Parameters:
    # $1 = name of xmp file
    # $2 = name of heic file
    assure_file_readable "$1"
    assure_file_readable "$2"
    echo "  Looking for GPS coordinates..."
    GPSLatitude=$(ggrep -P "(?<=<exif:GPSLatitude>)[0-9.]*" -o "$1")
    GPSLatitudeRef=$(ggrep -P "(?<=<exif:GPSLatitudeRef>)[A-Z]" -o "$1")
    GPSLongitude=$(ggrep -P "(?<=<exif:GPSLongitude>)[0-9.]*" -o "$1")
    GPSLongitudeRef=$(ggrep -P "(?<=<exif:GPSLongitudeRef>)[A-Z]" -o "$1")
    echo "  Found Lat = ${GPSLatitude}${GPSLatitudeRef} Long = ${GPSLongitude}${GPSLongitudeRef}"
    exiftool \
        -m \
        -overwrite_original \
        -GPS:GPSLatitude="${GPSLatitude}" \
        -GPS:GPSLatitudeRef=${GPSLatitudeRef} \
        -GPS:GPSLongitude="${GPSLongitude}" \
        -GPS:GPSLongitudeRef=${GPSLongitudeRef} \
        "$2"
}

main() {
    check_requirements

    j_file="$1"
    assure_file_readable "$j_file"

    h_file="${j_file%.*}.heic"  # https://stackoverflow.com/a/12152997

    convert_jpeg_to_heic "$j_file" "$h_file"

    # Check to see if an XMP file exists with the same name as the original file
    x_file="${j_file%.*}.xmp"
    if [ -r "$x_file" ]; then
        import_xmp_to_heic "$x_file" "$h_file"
        import_fixed_xmp_gps_to_heic "$x_file" "$h_file"
    fi
}

main "$*"

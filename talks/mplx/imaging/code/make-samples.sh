#!/bin/sh
# Creates the sample input pictures the programs read, with ImageMagick 7.
# They stand in for the photos used in the talk; any pictures of the same
# kind work.
set -e
cd "$(dirname "$0")"
# holiday.jpg: a 3000x2000 colour photo (info.j, edit.j)
magick -size 3000x2000 -seed 42 plasma:skyblue-forestgreen -quality 85 holiday.jpg
# phone.jpg: a 1600x1067 photo stored sideways, with EXIF orientation
# LeftBottom, as a phone writes it (magick.j, magickerr.j)
# (an EXIF block with only Orientation = 8 is spliced in after the JPEG
# start marker, since ImageMagick does not write one for a new image)
magick -size 1600x1067 -seed 7 plasma:orange-navy -rotate 270 -quality 85 \
    phone-raw.jpg
{
    head -c 2 phone-raw.jpg
    printf '\377\341\000\042Exif\000\000II*\000\010\000\000\000\001\000'
    printf '\022\001\003\000\001\000\000\000\010\000\000\000\000\000\000\000'
    tail -c +3 phone-raw.jpg
} > phone.jpg
rm phone-raw.jpg
# page.jpg: an A4 page at 150 dpi in grey, what the fake scanner returns
# (fakescanner.j)
magick -size 1240x1754 xc:white -fill gray20 -pointsize 36 \
    -annotate +150+250 'Dear reader,' \
    -annotate +150+330 'this page stands in for a scanned letter.' \
    -annotate +150+410 'Kind regards' \
    -attenuate 0.4 +noise Gaussian -colorspace Gray -quality 85 page.jpg
# logo.svg: a file ImageMagick is not allowed to read (magickerr.j)
printf '<svg/>\n' > logo.svg

#!/bin/sh
# make-media.sh - generate the talk's tiny test library with ffmpeg:
# four MP3s with messy tags in music/, a cover.png, and four short
# test-pattern films with NFO files in jellyfin/movies/. Nothing copyrighted.
set -eu
cd "$(dirname "$0")"
rm -rf music jellyfin
mkdir -p music jellyfin/movies jellyfin/music

ff() { ffmpeg -loglevel error -y "$@"; }
ff -f lavfi -i "sine=frequency=440:duration=7" -ac 2 -b:a 128k \
  -id3v2_version 3 -metadata title="  sine at dawn " \
  -metadata artist="the jennifers" -metadata album="Test Tones" \
  -metadata genre="(52)" -metadata track="1" "music/track01.mp3"
ff -f lavfi -i "sine=frequency=523:duration=5" -ac 2 -b:a 128k \
  -id3v2_version 3 -metadata title="SQUARE DANCE" \
  -metadata artist="The Jennifers" -metadata album="test tones" \
  -metadata genre="Electronic" -metadata track="2" "music/02 square dance.mp3"
ff -f lavfi -i "sine=frequency=330:duration=9" -ac 1 -b:a 96k \
  -id3v2_version 0 "music/03 - low hum.mp3"
ff -f lavfi -i "anoisesrc=d=6:c=pink:a=0.1" -ac 2 -b:a 160k "music/04 pink noise.mp3"
ff -f lavfi -i "testsrc2=size=300x300:duration=1" -frames:v 1 music/cover.png

film() { # folder title year minutes plot rating source genre
  mkdir -p "jellyfin/movies/$1"
  ff -f lavfi -i "$7=size=320x180:rate=10" -f lavfi -i "sine=frequency=220" \
    -t 4 -c:v libx264 -c:a aac "jellyfin/movies/$1/$1.mkv"
  cat > "jellyfin/movies/$1/movie.nfo" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<movie><title>$2</title><year>$3</year><runtime>$4</runtime><plot>$5</plot><rating>$6</rating><genre>$8</genre></movie>
EOF
}
film "The Test Pattern (2024)" "The Test Pattern" 2024 94 \
  "A broadcast engineer guards the last test card on air." 7.1 testsrc Drama
film "Colour Bars at Dawn (2023)" "Colour Bars at Dawn" 2023 121 \
  "Seven colours, one transmitter, no sleep." 6.4 smptebars Thriller
film "Sine Wave Serenade (2025)" "Sine Wave Serenade" 2025 88 \
  "A 440 Hz love story." 7.8 testsrc2 Romance
film "Mandelbrot Heist (2022)" "Mandelbrot Heist" 2022 107 \
  "The crew must zoom in forever to find the vault." 6.9 mandelbrot Comedy
echo "generated music/ and jellyfin/movies/"

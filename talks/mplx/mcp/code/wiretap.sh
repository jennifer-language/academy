#!/bin/sh
d=$(dirname "$0")
tee "$d/wire.in" | jennifer run "$d/docs.j" "$1" | tee "$d/wire.out"

#!/bin/sh
# What the gate catches: two broken copies of the built deck. The first
# adds an export, isCalm, with no test and no cheatsheet line (coverage and
# docs fail); the second appends a comment to a shared script (check-shared
# fails). The built deck itself is not changed.
#
# Usage: sh red-gate.sh [deck-dir]   (default: ./deck-beaufort-built)
set -u
here=$(cd "$(dirname "$0")" && pwd)
deck=${1:-$here/deck-beaufort-built}
work=$(mktemp -d)

cp -r "$deck" "$work/export"
cat >> "$work/export/src/beaufort.j" <<'JEN'

/**
 * Whether a wind speed is calm, force 0.
 *
 * @param kmh {int} the wind speed in km/h
 * @return {bool} true below 1 km/h
 */
export func isCalm(kmh as int) {
    return force($kmh) == 0;
}
JEN
(cd "$work/export" && tools/check-all.sh)

cp -r "$deck" "$work/shared"
echo "# a local tweak" >> "$work/shared/tools/check-src.sh"
(cd "$work/shared" && tools/check-shared.sh)
echo "the broken copies are in $work"

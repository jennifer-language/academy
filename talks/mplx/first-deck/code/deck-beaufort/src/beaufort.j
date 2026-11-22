# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * Wind speed to Beaufort force.
 *
 * @module beaufort
 */

# The lowest speed in km/h of forces 1 to 12; force 0 is below the first.
def const LIMITS as list of int init [1, 6, 12, 20, 29, 39, 50, 62, 75, 89, 103, 118];

/**
 * The Beaufort force of a wind speed.
 *
 * @param kmh {int} the wind speed in km/h, 0 or more
 * @return {int} the force, 0 (calm) to 12 (hurricane)
 * @throws beaufort when the speed is negative
 * @example
 *   beaufort.force(45);   # 6
 */
export func force(kmh as int) {
    if ($kmh < 0) {
        throw Error{kind: "beaufort", message: "beaufort: negative speed"};
    }
    def f as int init 0;
    while ($f < 12 and $kmh >= LIMITS[$f]) {
        $f = $f + 1;
    }
    return $f;
}

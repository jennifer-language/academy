# SPDX-License-Identifier: LGPL-3.0-only
# pragma-jennifer-version: >=0.26.0

/**
 * Write a number of seconds as a duration such as `1h30m`.
 * @module format
 */
use convert;

/**
 * Return seconds as hours, minutes and seconds, without zero parts.
 * @param total {int} the duration in seconds, not negative
 * @return {string} the duration, for example `1h30m`; `0s` for zero
 */
export func duration(total as int) {
    if ($total == 0) {
        return "0s";
    }
    def out as string init "";
    def h as int init $total // 3600;
    def m as int init $total % 3600 // 60;
    def s as int init $total % 60;
    if ($h > 0) {
        $out = $out + convert.toString($h) + "h";
    }
    if ($m > 0) {
        $out = $out + convert.toString($m) + "m";
    }
    if ($s > 0) {
        $out = $out + convert.toString($s) + "s";
    }
    return $out;
}

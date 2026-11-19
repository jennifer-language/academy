# SPDX-License-Identifier: LGPL-3.0-only
# pragma-jennifer-version: >=0.26.0

/**
 * Read a duration such as `1h30m` into seconds.
 * @module parse
 */
use convert;
use regex;

/**
 * Return the number of seconds in a duration of hours, minutes and seconds.
 * @param text {string} the duration, for example `1h30m` or `45s`
 * @return {int} the duration in seconds
 * @throws {Error} kind `tempo` when the text is not a duration
 */
export func seconds(text as string) {
    if (not regex.matches("^([0-9]+h)?([0-9]+m)?([0-9]+s)?$", $text) or $text == "") {
        throw Error{kind: "tempo", message: "not a duration: " + $text};
    }
    def total as int init 0;
    for (def part in regex.findAll("[0-9]+[hms]", $text)) {
        def n as int init convert.toInt($part.text[0..len($part.text) - 1]);
        def unit as string init $part.text[len($part.text) - 1..len($part.text)];
        if ($unit == "h") {
            $total = $total + $n * 3600;
        } elseif ($unit == "m") {
            $total = $total + $n * 60;
        } else {
            $total = $total + $n;
        }
    }
    return $total;
}

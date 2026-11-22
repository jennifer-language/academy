# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * The contributor declaration a pull request must carry, ticked.
 *
 * The items are in `.github/pull_request_template.md`. Each one is found by a
 * stable phrase from its text, so a deleted or reworded item counts as
 * missing, and it must be ticked (`- [x]`, either case).
 * @module declaration
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use regex;
use strings;

/** One phrase per declaration item, lower case, in the template's order. */
export def const PHRASES as list of string init [
    "i am the author of this talk and of every file it contains",
    "i license the talk under cc by 4.0",
    "the talk is lawful in my country and in the country from which the academy is published",
    "i am solely responsible for the content i submit under my github account",
    "the maintainers may decline, change or remove my talk at any time",
];

/** The state of every item: "ticked", "unticked" or "missing", in order. */
export func states(body as string) {
    return statesOf($body, PHRASES);
}

/**
 * The state of every checklist item, each found by its stable phrase: a line
 * `- [x] ...` (or `* [X] ...`) holding the phrase is "ticked", `- [ ] ...`
 * "unticked", and an item with no such line "missing".
 * @param {string} body the text holding the checklist
 * @param {list of string} phrases one lower-case phrase per item
 * @return {list of string} one state per phrase, in order
 */
export func statesOf(body as string, phrases as list of string) {
    def found as list of string;
    for (def p in $phrases) {
        $found[] = "missing";
    }
    def text as string init strings.replace($body, "\r\n", "\n");
    for (def line in strings.split($text, "\n")) {
        def m as regex.Match init regex.find('^\s*[-*]\s+\[([ xX])\]\s+(.*)$', $line);
        if ($m.start < 0) {
            continue;
        }
        def said as string init strings.lower(regex.replace('\s+', $m.groups[1], " "));
        for (def i in 0..len($phrases)) {
            if (not strings.contains($said, $phrases[$i]) or $found[$i] == "ticked") {
                continue;
            }
            $found[$i] = "unticked";
            if ($m.groups[0] != " ") {
                $found[$i] = "ticked";
            }
        }
    }
    return $found;
}

/**
 * What is wrong with a pull request's declaration.
 * @param {string} body the pull request description
 * @return {list of string} one message per item not ticked; empty when all are
 */
export func problems(body as string) {
    def out as list of string;
    def st as list of string init states($body);
    for (def i in 0..len(PHRASES)) {
        if ($st[$i] == "ticked") {
            continue;
        }
        def n as int init $i + 1;
        def phrase as string init PHRASES[$i];
        $out[] = "declaration item {$n} is {$st[$i]}: \"{$phrase} ...\"";
    }
    return $out;
}

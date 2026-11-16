# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * Tests for the declaration check: the template itself, ticked, unticked,
 * missing and reworded items.
 * @module declarationTest
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use fs;
use testing;

/** The template as shipped, unticked; path relative to the repository root. */
func template() {
    return fs.readString(".github/pull_request_template.md");
}

/** The template with every box ticked. */
func ticked() {
    return strings.replace(template(), "- [ ]", "- [x]");
}

func testTemplateHasEveryItemUnticked() {
    testing.assertEqual(
        states(template()),
        ["unticked", "unticked", "unticked", "unticked", "unticked"]);
    testing.assertEqual(len(problems(template())), 5);
}

func testAllTickedPasses() {
    testing.assertEqual(problems(ticked()), []);
    testing.assertEqual(problems(strings.replace(template(), "- [ ]", "* [X]")), []);
    testing.assertEqual(problems(strings.replace(ticked(), "\n", "\r\n")), []);
}

func testOneUntickedFails() {
    def body as string init strings.replace(ticked(), "- [x] I license", "- [ ] I license");
    testing.assertEqual(states($body), ["ticked", "unticked", "ticked", "ticked", "ticked"]);
    def found as list of string init problems($body);
    testing.assertEqual(len($found), 1);
    testing.assertContains($found[0], "item 2 is unticked");
}

func testMissingItemFails() {
    def lines as list of string;
    for (def line in strings.split(ticked(), "\n")) {
        if (not strings.contains($line, "solely responsible")) {
            $lines[] = $line;
        }
    }
    testing.assertEqual(
        states(strings.join($lines, "\n")),
        ["ticked", "ticked", "ticked", "missing", "ticked"]);
}

func testRewordedItemFails() {
    def body as string init strings.replace(
        ticked(),
        "I am solely responsible",
        "I am partly responsible");
    testing.assertEqual(states($body)[3], "missing");
}

func testEmptyBodyFails() {
    testing.assertEqual(states(""), ["missing", "missing", "missing", "missing", "missing"]);
}

func testTickOutsideAListDoesNotCount() {
    def body as string init strings.replace(ticked(), "- [x] I license", "[x] I license");
    testing.assertEqual(states($body)[1], "missing");
}

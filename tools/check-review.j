#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * Check that a pull request with non-English talk content has its
 * translation review (CONTRIBUTING.md, "Review of talks in other languages").
 *
 *   jennifer run tools/check-review.j FILES REVIEWS
 *
 * FILES lists the paths the pull request adds or changes, one per line;
 * REVIEWS holds its reviews, one JSON object per line. The environment gives
 * PR_AUTHOR, PR_ASSOCIATION (the author's association) and HEAD_SHA. Run from
 * the repository root, checked out at the pull request's head. Exits 0 when
 * no non-English talk file changed, when the author is a maintainer, or when
 * a maintainer's approval with the ticked declaration is on the head commit.
 * @module checkReview
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use fs;
use io;
use lists;
use os;
use strings;

import "./review.j" as review;

/** An environment variable, or "". */
func env(name as string) {
    if (os.hasEnv($name)) {
        return os.getEnv($name);
    }
    return "";
}

if (len(os.ARGS) != 3) {
    io.eprintf("usage: check-review.j FILES REVIEWS\n");
    exit 2;
}
def changed as list of string;
for (def line in strings.split(fs.readString(os.ARGS[1]), "\n")) {
    if (strings.trim($line) != "") {
        $changed[] = strings.trim($line);
    }
}
def foreign as list of string init review.nonEnglish(".", $changed);
if (len($foreign) == 0) {
    io.printf("translation review: no non-English talk file changed\n");
    exit 0;
}
io.printf("non-English talk files:\n");
for (def f in $foreign) {
    io.printf("  %s\n", $f);
}
if (lists.contains(review.MAINTAINERS, env("PR_ASSOCIATION"))) {
    io.printf(
        "translation review: the author is a maintainer (%s); exempt\n",
        env("PR_ASSOCIATION"));
    exit 0;
}
def reviews as list of review.Review init review.parseReviews(fs.readString(os.ARGS[2]));
def problems as list of string init review.verdict($reviews, env("PR_AUTHOR"), env("HEAD_SHA"));
for (def p in $problems) {
    io.printf("%s\n", $p);
}
if (len($problems) > 0) {
    io.printf("A maintainer approves the head commit with the reviewer declaration\n");
    io.printf("from CONTRIBUTING.md (\"Review of talks in other languages\"), ticked.\n");
    exit 1;
}
io.printf("translation review: approved with the reviewer declaration\n");

#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * Write a buildable copy of one talk: talk.md with the catalogue fields of
 * academy.toml injected into its front matter, plus its images.
 *
 *   jennifer run tools/prepare.j talks/<user>/<topic> OUT
 *
 * Prints the prepared talk.md's path; exits 1 when academy.toml is invalid.
 * @module prepare
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use io;
use os;
use path;

import "./meta.j" as meta;
import "./rules.j" as rules;

if (len(os.ARGS) != 3) {
    io.eprintf("usage: prepare.j TALK-DIR OUT-DIR\n");
    exit 2;
}
def dir as string init os.ARGS[1];
def user as string init path.base(path.dir($dir));
def entry as meta.Checked init rules.readMeta($dir, $user);
for (def p in $entry.problems) {
    io.eprintf("%s/academy.toml: %s\n", $dir, $p);
}
if (len($entry.problems) > 0) {
    exit 1;
}
io.printf("%s\n", rules.prepare($dir, $entry.meta, os.ARGS[2]));

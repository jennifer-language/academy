#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * Write a buildable copy of every language version of one talk: its talk
 * file with the catalogue fields of academy.toml injected into the front
 * matter, plus the talk's images, into OUT/<lang>/talk.md.
 *
 *   jennifer run tools/prepare.j talks/<user>/<topic> OUT
 *
 * Prints one line per version, `<lang> <primary|translation> <path>`, the
 * primary language first; exits 1 when academy.toml is invalid.
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
for (def v in meta.versionsOf($entry.meta)) {
    def kind as string init "translation";
    if ($v.primary) {
        $kind = "primary";
    }
    def out as string init path.join(os.ARGS[2], $v.lang);
    io.printf("%s %s %s\n", $v.lang, $kind, rules.prepare($dir, $entry.meta, $v, $out));
}

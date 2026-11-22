#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * Check that a pull request carries the ticked contributor declaration.
 *
 *   PR_BODY="$(cat body.md)" jennifer run tools/check-declaration.j
 *
 * CI passes the pull request's description in `PR_BODY` (through the
 * environment, never through the shell). Exits 1 when an item is missing or
 * not ticked, naming each one.
 * @module checkDeclaration
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use io;
use os;

import "./declaration.j" as declaration;

def body as string init "";
if (os.hasEnv("PR_BODY")) {
    $body = os.getEnv("PR_BODY");
}
def found as list of string init declaration.problems($body);
for (def p in $found) {
    io.printf("%s\n", $p);
}
if (len($found) > 0) {
    io.printf("Copy the contributor declaration from .github/pull_request_template.md into the\n");
    io.printf("pull request description and tick every item (see CONTRIBUTING.md).\n");
    exit 1;
}
io.printf("declaration: all %d items ticked\n", len(declaration.PHRASES));

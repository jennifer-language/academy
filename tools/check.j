#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0
# pragma-jennifer-capability: exec

/**
 * Check every talk against the academy's rules (CONTRIBUTING.md).
 *
 *   jennifer run tools/check.j                 # every talk
 *   jennifer run tools/check.j talks/u/topic   # some talks
 *   jennifer run tools/check.j --fast          # skip parsing code and building
 *
 * Run it from the repository root. `JENNIFER` names the interpreter used for
 * the code blocks and for cantrip (default `jennifer`), `CANTRIP` the cantrip
 * launcher (default: `../apps/cantrip/bin/cantrip`, the workspace's checkout,
 * when it exists, else `cantrip` on PATH; CI sets it to its own clone).
 * Prints one `file:line: rule: message` line per problem and exits 1 when
 * there is any.
 * @module check
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use fs;
use io;
use lists;
use os;
use path;
use regex;
use strings;

import "./rules.j" as rules;

/** A configured path from the environment, else the fallback. */
func setting(name as string, fallback as string) {
    if (os.hasEnv($name) and os.getEnv($name) != "") {
        return os.getEnv($name);
    }
    return $fallback;
}

/** Files outside talks/ that the dash rule also covers. */
func repoTextFiles() {
    def out as list of string;
    for (def top in ["README.md", "CONTRIBUTING.md", "imprint.md", "CLAUDE.md"]) {
        if (fs.isFile($top)) {
            $out[] = $top;
        }
    }
    for (def dir in ["tools", ".github"]) {
        for (def st in fs.walk($dir)) {
            def ext as string init path.ext($st.path);
            if (not $st.isDir and lists.contains([".j", ".sh", ".yml", ".md"], $ext)) {
                $out[] = $st.path;
            }
        }
    }
    return $out;
}

def opts as rules.Options init rules.Options{
    jennifer: setting("JENNIFER", "jennifer"),
    cantrip: setting("CANTRIP", "cantrip"),
    parseCode: true,
    build: true,
};
def wanted as list of string;
for (def arg in os.ARGS[1..]) {
    if ($arg == "--fast") {
        $opts.parseCode = false;
        $opts.build = false;
    } elseif (strings.startsWith($arg, "-")) {
        io.eprintf("check: unknown option %s\n", $arg);
        exit 2;
    } else {
        $wanted[] = regex.replace("/+$", $arg, "");
    }
}
if (not os.hasEnv("CANTRIP") and fs.isFile("../apps/cantrip/bin/cantrip")) {
    $opts.cantrip = "../apps/cantrip/bin/cantrip";
}

def findings as list of rules.Finding init rules.checkLayout("talks");
def count as int init 0;
if (fs.isDir("talks")) {
    for (def user in fs.list("talks")) {
        if (not fs.isDir(path.join("talks", $user))) {
            continue;
        }
        for (def topic in fs.list(path.join("talks", $user))) {
            def dir as string init path.join("talks", $user, $topic);
            if (not fs.isDir($dir) or (len($wanted) > 0 and not lists.contains($wanted, $dir))) {
                continue;
            }
            $count = $count + 1;
            for (def f in rules.checkTalk($dir, $user, $opts)) {
                $findings[] = $f;
            }
        }
    }
}
for (def file in repoTextFiles()) {
    for (def f in rules.checkDashes($file, fs.readString($file))) {
        $findings[] = $f;
    }
}

for (def f in $findings) {
    io.printf("%s\n", rules.describe($f));
}
if (len($findings) > 0) {
    io.printf("check: %d problem(s) in %d talk(s)\n", len($findings), $count);
    exit 1;
}
io.printf("check: %d talk(s) pass\n", $count);

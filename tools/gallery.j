#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * Write the academy's own pages into the site directory.
 *
 *   jennifer run tools/gallery.j [talks [site]]   # defaults: talks, site
 *
 * Reads every talk's academy.toml and writes `index.html`, one
 * `<user>/index.html` per author, one `tags/<tag>/index.html` per tag,
 * `imprint/index.html` from `imprint.md`, `sitemap.xml`, `robots.txt` and
 * `talks.json`, and adds a canonical link to each built slideshow. Run it
 * from the repository root after `tools/build.sh` has built the talks (the
 * script calls it); it refuses a talk whose academy.toml is invalid.
 * @module gallery
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use fs;
use io;
use lists;
use os;
use path;

import "./meta.j" as meta;
import "./rules.j" as rules;
import "./site.j" as site;

def talks as string init "talks";
def out as string init "site";
if (len(os.ARGS) > 1) {
    $talks = os.ARGS[1];
}
if (len(os.ARGS) > 2) {
    $out = os.ARGS[2];
}

def all as list of site.Talk;
def bad as int init 0;
for (def user in fs.list($talks)) {
    if (not fs.isDir(path.join($talks, $user))) {
        continue;
    }
    for (def topic in fs.list(path.join($talks, $user))) {
        def dir as string init path.join($talks, $user, $topic);
        if (not fs.isDir($dir)) {
            continue;
        }
        def entry as meta.Checked init rules.readMeta($dir, $user);
        for (def p in $entry.problems) {
            io.eprintf("%s/academy.toml: %s\n", $dir, $p);
            $bad = $bad + 1;
        }
        $all[] = site.Talk{user: $user, topic: $topic, meta: $entry.meta};
    }
}
if ($bad > 0) {
    io.eprintf("gallery: fix academy.toml first (jennifer run tools/check.j)\n");
    exit 1;
}
$all = site.sorted($all);

fs.mkdirAll($out);
fs.writeString(path.join($out, "index.html"), site.indexPage($all));
def users as list of string;
for (def t in $all) {
    if (not lists.contains($users, $t.user)) {
        $users[] = $t.user;
        fs.mkdirAll(path.join($out, $t.user));
        fs.writeString(path.join($out, $t.user, "index.html"), site.userPage($all, $t.user));
    }
    def slides as string init path.join($out, $t.user, $t.topic, "index.html");
    if (fs.isFile($slides)) {
        fs.writeString($slides, site.withCanonical(fs.readString($slides), $t));
    }
}
def tags as list of string init site.tagsOf($all);
for (def tag in $tags) {
    fs.mkdirAll(path.join($out, "tags", $tag));
    fs.writeString(path.join($out, "tags", $tag, "index.html"), site.tagPage($all, $tag));
}
fs.mkdirAll(path.join($out, "imprint"));
fs.writeString(
    path.join($out, "imprint", "index.html"),
    site.imprintPage(fs.readString("imprint.md")));
fs.writeString(path.join($out, "sitemap.xml"), site.sitemap($all));
fs.writeString(path.join($out, "robots.txt"), site.robots());
fs.writeString(path.join($out, "talks.json"), site.catalogue($all));
io.printf(
    "gallery: %d talk(s), %d author(s), %d tag(s) in %s\n",
    len($all),
    len($users),
    len($tags),
    $out);

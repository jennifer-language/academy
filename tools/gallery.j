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
 * one `levels/<level>/index.html` per level, `legal/index.html` from `legal.md`,
 * `sitemap.xml`, `robots.txt`, `talks.json` and `llms.txt`, and adds canonical
 * and hreflang links to each built slideshow, one per language version. Run it
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
use regex;
use strings;

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

# gitDay is the day (YYYY-MM-DD) of the last commit that touched `dir`, or ""
# when there is no git, no history for it (a talk not committed yet), or only a
# shallow clone, whose single commit would date every talk alike.
func gitDay(dir as string, history as bool) {
    if (not $history) {
        return "";
    }
    def r as os.Result;
    try {
        $r = os.run(["git", "log", "-1", "--format=%cs", "--", $dir]);
    } catch (e) {
        return "";
    }
    def day as string init strings.trim($r.stdout);
    if ($r.exitCode != 0 or not regex.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$', $day)) {
        return "";
    }
    return $day;
}

# fullHistory says whether this is a git checkout with its whole history.
func fullHistory() {
    def r as os.Result;
    try {
        $r = os.run(["git", "rev-parse", "--is-shallow-repository"]);
    } catch (e) {
        return false;
    }
    if ($r.exitCode != 0) {
        return false;
    }
    if (strings.trim($r.stdout) == "true") {
        io.eprintf("gallery: shallow clone, so no git dates (fetch with depth 0)\n");
        return false;
    }
    return true;
}

def history as bool init fullHistory();
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
        $all[] = site.Talk{
            user: $user,
            topic: $topic,
            meta: $entry.meta,
            modified: gitDay($dir, $history)
        };
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
    for (def v in meta.versionsOf($t.meta)) {
        def slides as string init path.join($out, $t.user, $t.topic, "index.html");
        if (not $v.primary) {
            $slides = path.join($out, $t.user, $t.topic, $v.lang, "index.html");
        }
        if (fs.isFile($slides)) {
            fs.writeString($slides, site.withHead(fs.readString($slides), $t, $v));
        }
    }
}
def tags as list of string init site.tagsOf($all);
for (def tag in $tags) {
    fs.mkdirAll(path.join($out, "tags", $tag));
    fs.writeString(path.join($out, "tags", $tag, "index.html"), site.tagPage($all, $tag));
}
for (def level in site.levelsOf($all)) {
    fs.mkdirAll(path.join($out, "levels", $level));
    fs.writeString(path.join($out, "levels", $level, "index.html"), site.levelPage($all, $level));
}
fs.mkdirAll(path.join($out, "legal"));
fs.writeString(path.join($out, "legal", "index.html"), site.legalPage(fs.readString("legal.md")));
fs.writeString(path.join($out, "sitemap.xml"), site.sitemap($all));
fs.writeString(path.join($out, "robots.txt"), site.robots());
fs.writeString(path.join($out, "talks.json"), site.catalogue($all));
fs.writeString(path.join($out, "llms.txt"), site.llmsTxt($all));
io.printf(
    "gallery: %d talk(s), %d author(s), %d tag(s) in %s\n",
    len($all),
    len($users),
    len($tags),
    $out);

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
 * and hreflang links to each built slideshow, one per language version. A
 * talk's code/ is published at `talks/<user>/<topic>/code/` (every file, a
 * listing with README.md rendered, a page showing each text file) and as
 * `<topic>-code.zip`; its translations share it. Run it
 * from the repository root after `tools/build.sh` has built the talks (the
 * script calls it); it refuses a talk whose academy.toml is invalid.
 * @module gallery
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use archive;
use convert;
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

# codeOf lists the files of a talk's code folder, none when it has no code/.
func codeOf(dir as string) {
    def files as list of site.CodeFile;
    def code as string init path.join($dir, rules.CODE_DIR);
    if (not fs.isDir($code)) {
        return $files;
    }
    for (def e in rules.codeFiles($code)) {
        $files[] = site.CodeFile{path: $e.rel, size: $e.size, text: rules.isCodeText($e.rel)};
    }
    return $files;
}

# highlightAll runs `cantrip highlight` once over every text file a code page
# shows, into a new temporary directory it returns ("" when there is no code):
# the fragment of talks/<user>/<topic>/code/<path> is <dir>/<that path>.html.
# CANTRIP names the cantrip launcher (tools/build.sh sets it), run with
# JENNIFER; the talks directory must be relative, as cantrip writes below --out.
func highlightAll(talksDir as string, all as list of site.Talk) {
    def files as list of string;
    for (def t in $all) {
        for (def f in $t.code) {
            if ($f.text and not site.zipOnly($f)) {
                $files[] = path.join($talksDir, $t.user, $t.topic, rules.CODE_DIR, $f.path);
            }
        }
    }
    if (len($files) == 0) {
        return "";
    }
    def cantrip as string init os.getEnv("CANTRIP");
    if ($cantrip == "") {
        io.eprintf("gallery: CANTRIP names the cantrip launcher (tools/build.sh sets it)\n");
        exit 1;
    }
    def jennifer as string init os.getEnv("JENNIFER");
    if ($jennifer == "") {
        $jennifer = "jennifer";
    }
    def dir as string init fs.makeTempDir();
    def cmd as list of string init [$jennifer, "run", $cantrip, "highlight", "--out", $dir];
    for (def f in $files) {
        $cmd[] = $f;
    }
    def r as os.Result init os.run($cmd);
    if ($r.exitCode != 0) {
        io.eprintf("%s", $r.stderr);
        io.eprintf("gallery: cantrip highlight failed\n");
        fs.removeAll($dir);
        exit 1;
    }
    return $dir;
}

# writeCode publishes a talk's code folder below `dest` (the talk's directory
# in the site): the files, the listing, a page per text file with the fragment
# highlightAll wrote below `hl`, and the zip.
func writeCode(t as site.Talk, dir as string, dest as string, hl as string) {
    def code as string init path.join($dir, rules.CODE_DIR);
    def target as string init path.join($dest, "code");
    def members as list of archive.Entry;
    def readme as string init "";
    for (def f in $t.code) {
        def data as bytes init fs.readBytes(path.join($code, $f.path));
        $members[] = archive.Entry{name: $f.path, data: $data, mode: 0o644, mtime: 0};
        if (site.zipOnly($f)) {
            continue;
        }
        def p as string init path.join($target, $f.path);
        fs.mkdirAll(path.dir($p));
        fs.writeBytes($p, $data);
        if (not $f.text) {
            continue;
        }
        def text as string init convert.stringFromBytes("utf-8", $data);
        def shown as string init fs.readString(path.join($hl, $code, $f.path + ".html"));
        fs.writeString(path.join($target, site.viewPath($f)), site.codeFilePage($t, $f, $shown));
        if ($f.path == rules.CODE_README) {
            $readme = $text;
        }
    }
    fs.writeString(path.join($target, "index.html"), site.codePage($t, $readme));
    fs.writeBytes(path.join($dest, $t.topic + "-code.zip"), site.codeZip($t, $members));
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
            modified: gitDay($dir, $history),
            code: codeOf($dir)
        };
    }
}
if ($bad > 0) {
    io.eprintf("gallery: fix academy.toml first (jennifer run tools/check.j)\n");
    exit 1;
}
$all = site.sorted($all);

def hl as string init highlightAll($talks, $all);

fs.mkdirAll($out);
fs.writeString(path.join($out, "index.html"), site.indexPage($all));
def users as list of string;
def talksRoot as string init path.join($out, "talks");
for (def t in $all) {
    if (not lists.contains($users, $t.user)) {
        $users[] = $t.user;
        fs.mkdirAll(path.join($talksRoot, $t.user));
        fs.writeString(path.join($talksRoot, $t.user, "index.html"), site.userPage($all, $t.user));
    }
    if (site.hasCode($t)) {
        writeCode(
            $t,
            path.join($talks, $t.user, $t.topic),
            path.join($talksRoot, $t.user, $t.topic),
            $hl);
    }
    for (def v in meta.versionsOf($t.meta)) {
        def rel as string init path.join($t.user, $t.topic);
        if (not $v.primary) {
            $rel = path.join($rel, $v.lang);
        }
        def slides as string init path.join($talksRoot, $rel, "index.html");
        if (fs.isFile($slides)) {
            fs.writeString($slides, site.withHead(fs.readString($slides), $t, $v));
        }
        # A talk published before the move keeps its old address as a redirect.
        if (site.isLegacy($t)) {
            fs.mkdirAll(path.join($out, $rel));
            def target as string init site.SITE_URL + site.TALKS_DIR + $rel + "/";
            fs.writeString(path.join($out, $rel, "index.html"), site.redirectPage($target));
        }
    }
}
if ($hl != "") {
    fs.removeAll($hl);
}
for (def u in $users) {
    if (lists.contains(site.RESERVED_NAMES, $u)) {
        continue;
    }
    def legacyUser as bool init false;
    for (def t in $all) {
        if ($t.user == $u and site.isLegacy($t)) {
            $legacyUser = true;
        }
    }
    if ($legacyUser) {
        fs.mkdirAll(path.join($out, $u));
        fs.writeString(
            path.join($out, $u, "index.html"),
            site.redirectPage(site.SITE_URL + site.userPath($u)));
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

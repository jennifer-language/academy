# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0
# pragma-jennifer-capability: exec

/**
 * The academy's contribution rules, as functions.
 *
 * `tools/check.j` runs them over the tree and `tools/gallery.j` reads the
 * front matter through them; `rules_test.j` holds the negative cases. Each
 * rule returns `Finding`s rather than printing, so a caller decides how to
 * report them. The rules themselves are written down in CONTRIBUTING.md.
 * @module rules
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use convert;
use fs;
use lists;
use maps;
use os;
use path;
use regex;
use strings;

import "./meta.j" as meta;

# ---------------------------------------------------------------------------
# The link allowlist. This is the one place it is defined; CONTRIBUTING.md
# documents it. A URL is allowed when its host is ALLOWED_DOMAIN or one of its
# subdomains, or when it is on github.com under one of GITHUB_OWNERS, under the
# talk's own namespace user, or exactly one of GITHUB_PATHS.
# ---------------------------------------------------------------------------

/** The project's domain; it and every subdomain of it are allowed. */
export def const ALLOWED_DOMAIN as string init "jennifer-lang.dev";

/** GitHub accounts of the project whose pages and repositories may be linked. */
export def const GITHUB_OWNERS as list of string init ["jennifer-language", "deckyard", "mplx"];

/** Single GitHub pages outside those accounts that may be linked. */
export def const GITHUB_PATHS as list of string init ["topics/grimoire-plugin"];

/** Organisations that can never be a talk's namespace. */
export def const DENIED_NAMESPACES as list of string init ["jennifer-language", "deckyard"];

/** Front-matter keys a talk may set: how it is presented. The rest comes from academy.toml. */
export def const FRONT_KEYS as list of string init ["theme", "ratio", "transition"];

/** Front-matter keys every talk must set. */
export def const FRONT_REQUIRED as list of string init ["theme"];

/** File extensions a talk directory may hold besides `talk.md`. */
export def const IMAGE_EXTENSIONS as list of string init [".png", ".jpg", ".jpeg", ".gif"];

/** The word in a fence's info string that marks a block as an excerpt. */
export def const EXCERPT as string init "excerpt";

# The longer messages, kept here so the checks stay readable.
def const MSG_NAMESPACE_DIR as string init
    "talks/ holds only namespace directories, one per GitHub user";
def const MSG_BAD_USER as string init
    "is not a GitHub user name in lower case (a-z, 0-9, single inner hyphens, at most 39)";
def const MSG_ORG as string init
    "is an organisation; a talk is published under its author's personal account";
def const MSG_TOPIC_DIR as string init
    "a namespace holds only talk directories, talks/<user>/<topic>/";
def const MSG_BAD_SLUG as string init
    "is not a valid slug: lowercase a-z, 0-9 and single inner hyphens";
def const MSG_NO_TALK as string init "a talk directory holds exactly one talk, named talk.md";
def const MSG_NO_META as string init "a talk directory holds its catalogue entry, academy.toml";
def const MSG_SUBDIR as string init "no subdirectories in a talk; keep its images beside talk.md";
def const MSG_OTHER_FILE as string init
    "a talk directory holds talk.md, academy.toml and images (.png, .jpg, .jpeg, .gif) only";

/** One broken rule: where, which rule, and what to do about it. */
export def struct Finding {
    file as string,
    line as int,
    rule as string,
    message as string
};

/** What the slow rules need: the interpreter and cantrip, and which to run. */
export def struct Options {
    jennifer as string,
    cantrip as string,
    parseCode as bool,
    build as bool
};

/** A talk's front matter: its keys (lower-cased) and the line after the block. */
export def struct FrontMatter {
    found as bool,
    values as map of string to string,
    lines as map of string to int,
    bodyStart as int
};

/** A URL found in a talk, with the line it is on and whether it is an image. */
export def struct UrlRef {
    line as int,
    url as string,
    image as bool
};

/** A fenced code block: where it opens, its info string, and its text. */
export def struct Block {
    line as int,
    info as string,
    text as string
};

/** A slide: the line it starts on, whether it has text, and whether it has notes. */
export def struct Slide {
    line as int,
    hasText as bool,
    hasNotes as bool,
    visible as list of string
};

/** The lines of a talk, each marked as inside a fenced block or not. */
export def struct Scan {
    lines as list of string,
    fenced as list of bool,
    blocks as list of Block
};

/** Build a finding. */
func finding(file as string, line as int, rule as string, message as string) {
    return Finding{file: $file, line: $line, rule: $rule, message: $message};
}

# ---------------------------------------------------------------------------
# Names and paths
# ---------------------------------------------------------------------------

/**
 * Is this a valid GitHub login, written in lower case?
 * @param {string} name the directory name
 * @return {bool} true for 1 to 39 of `a-z0-9` and single inner hyphens
 */
export func isValidUser(name as string) {
    if (len($name) < 1 or len($name) > 39) {
        return false;
    }
    return regex.matches('^[a-z0-9]+(-[a-z0-9]+)*$', $name);
}

/**
 * Is this a valid topic slug, the last part of a talk's URL?
 * @param {string} name the directory name
 * @return {bool} true for lowercase `a-z0-9` words joined by single hyphens
 */
export func isValidSlug(name as string) {
    if (len($name) < 1 or len($name) > 64) {
        return false;
    }
    return regex.matches('^[a-z0-9]+(-[a-z0-9]+)*$', $name);
}

/** The extension of a file name, lower-cased. */
func lowerExt(name as string) {
    return strings.lower(path.ext($name));
}

/** Is `child` (a resolved path) inside the directory `dir` (resolved)? */
func isInside(dir as string, child as string) {
    return strings.startsWith($child, $dir + "/");
}

/**
 * Check the tree under `talks/`: namespaces, slugs, and what a talk
 * directory may hold (rule 7, plus the namespace rules).
 * @param {string} root the `talks` directory
 * @return {list of Finding} one per problem
 */
export func checkLayout(root as string) {
    def out as list of Finding;
    if (not fs.isDir($root)) {
        $out[] = finding($root, 0, "layout", "no talks directory");
        return $out;
    }
    def realRoot as string init fs.realpath($root);
    for (def user in fs.list($root)) {
        def userDir as string init path.join($root, $user);
        if (not fs.isDir($userDir) or fs.realpath($userDir) != path.join($realRoot, $user)) {
            $out[] = finding($userDir, 0, "layout", MSG_NAMESPACE_DIR);
            continue;
        }
        if (not isValidUser($user)) {
            $out[] = finding($userDir, 0, "namespace", "\"{$user}\" " + MSG_BAD_USER);
        }
        if (lists.contains(DENIED_NAMESPACES, $user)) {
            $out[] = finding($userDir, 0, "namespace", "\"{$user}\" " + MSG_ORG);
        }
        def topics as list of string init fs.list($userDir);
        if (len($topics) == 0) {
            $out[] = finding($userDir, 0, "layout", "empty namespace directory");
        }
        for (def topic in $topics) {
            def dir as string init path.join($userDir, $topic);
            if (not fs.isDir($dir) or fs.realpath($dir) != path.join($realRoot, $user, $topic)) {
                $out[] = finding($dir, 0, "layout", MSG_TOPIC_DIR);
                continue;
            }
            if (not isValidSlug($topic)) {
                $out[] = finding($dir, 0, "layout", "\"{$topic}\" " + MSG_BAD_SLUG);
            }
            for (def f in checkTalkDir($dir)) {
                $out[] = $f;
            }
        }
    }
    return $out;
}

/** Append the findings for what a single talk directory holds. */
func checkTalkDir(dir as string) {
    def out as list of Finding;
    def real as string init fs.realpath($dir);
    if (not fs.isFile(path.join($dir, "talk.md"))) {
        $out[] = finding($dir, 0, "layout", MSG_NO_TALK);
    }
    if (not fs.isFile(path.join($dir, "academy.toml"))) {
        $out[] = finding($dir, 0, "layout", MSG_NO_META);
    }
    for (def name in fs.list($dir)) {
        def p as string init path.join($dir, $name);
        if (fs.isDir($p)) {
            $out[] = finding($p, 0, "layout", MSG_SUBDIR);
            continue;
        }
        if (fs.realpath($p) != path.join($real, $name)) {
            $out[] = finding($p, 0, "layout", "no symbolic links in a talk");
            continue;
        }
        if ($name == "talk.md" or $name == "academy.toml") {
            continue;
        }
        if (not lists.contains(IMAGE_EXTENSIONS, lowerExt($name))) {
            $out[] = finding($p, 0, "layout", MSG_OTHER_FILE);
        }
    }
    return $out;
}

# ---------------------------------------------------------------------------
# Reading a talk
# ---------------------------------------------------------------------------

/**
 * Read the front matter: a `---` block on line 1, `name: value` per line.
 * Mirrors cantrip: keys are lower-cased, values unquoted, `#` lines skipped.
 * @param {list of string} lines the talk's lines
 * @return {FrontMatter} found is false when line 1 opens no closed block
 */
export func frontMatter(lines as list of string) {
    def fm as FrontMatter init FrontMatter{found: false, values: {}, lines: {}, bodyStart: 0};
    if (len($lines) == 0 or strings.trim($lines[0]) != "---") {
        return $fm;
    }
    def end as int init -1;
    for (def i in 1..len($lines)) {
        if (strings.trim($lines[$i]) == "---") {
            $end = $i;
            break;
        }
    }
    if ($end < 0) {
        return $fm;
    }
    $fm.found = true;
    $fm.bodyStart = $end + 1;
    for (def i in 1..$end) {
        def line as string init strings.trim($lines[$i]);
        if ($line == "" or strings.startsWith($line, "#")) {
            continue;
        }
        def colon as int init strings.indexOf($line, ":");
        if ($colon < 1) {
            continue;
        }
        def key as string init strings.lower(strings.trim(strings.substring($line, 0, $colon)));
        def raw as string init strings.substring($line, $colon + 1, len($line));
        def value as string init unquote(strings.trim($raw));
        $fm.values[$key] = $value;
        $fm.lines[$key] = $i + 1;
    }
    return $fm;
}

/** Strip one pair of matching quotes around a value. */
func unquote(v as string) {
    if (len($v) >= 2) {
        def first as string init $v[0..1];
        def last as string init $v[len($v) - 1..len($v)];
        if ($first == $last and ($first == "\"" or $first == "'")) {
            return $v[1..len($v) - 1];
        }
    }
    return $v;
}

/** The fence a line opens or closes (its run of backticks or tildes), or "". */
func fenceRun(line as string) {
    def m as list of string init lineMatch('^ {0,3}(`{3,}|~{3,})(.*)$', $line);
    if (len($m) == 0) {
        return "";
    }
    return $m[1];
}

/** The groups of the first match of `pattern` in `s`, the whole match first; [] if none. */
func lineMatch(pattern as string, s as string) {
    def m as regex.Match init regex.find($pattern, $s);
    def out as list of string;
    if ($m.start < 0) {
        return $out;
    }
    $out[] = $m.text;
    for (def g in $m.groups) {
        $out[] = $g;
    }
    return $out;
}

/**
 * Mark which lines are inside fenced code and collect the blocks. A fence
 * closes on a line of the same character, at least as long, and nothing else.
 * @param {list of string} lines the talk's lines
 * @return {Scan} the lines, a fenced flag per line, and the blocks
 */
export func scan(lines as list of string) {
    def fenced as list of bool;
    def blocks as list of Block;
    def open as string init "";
    def openInfo as string init "";
    def start as int init 0;
    def body as list of string;
    for (def i in 0..len($lines)) {
        def line as string init $lines[$i];
        if ($open == "") {
            def run as string init fenceRun($line);
            def info as string init fenceInfo($line);
            def inlineCode as bool init strings.startsWith($run, "`") and
                strings.contains($info, "`");
            if ($run != "" and not $inlineCode) {
                $open = $run;
                $openInfo = $info;
                $start = $i + 1;
                $body = [];
                $fenced[] = true;
                continue;
            }
            $fenced[] = false;
            continue;
        }
        $fenced[] = true;
        def close as string init fenceRun($line);
        if (isClosing($line, $close, $open)) {
            $blocks[] = Block{
                line: $start,
                info: $openInfo,
                text: strings.join($body, "\n") + "\n"
            };
            $open = "";
            continue;
        }
        $body[] = $line;
    }
    if ($open != "") {
        $blocks[] = Block{line: $start, info: $openInfo, text: strings.join($body, "\n") + "\n"};
    }
    return Scan{lines: $lines, fenced: $fenced, blocks: $blocks};
}

/** Does `line` (whose fence run is `close`) close a block opened with `open`? */
func isClosing(line as string, close as string, open as string) {
    if ($close == "" or $close[0..1] != $open[0..1] or len($close) < len($open)) {
        return false;
    }
    return regex.matches('^ {0,3}(`+|~+)\s*$', $line);
}

/** The info string after a fence, trimmed. */
func fenceInfo(line as string) {
    def m as list of string init lineMatch('^ {0,3}(`{3,}|~{3,})(.*)$', $line);
    if (len($m) == 0) {
        return "";
    }
    return strings.trim($m[2]);
}

/**
 * Remove inline code spans from a line, so their text is not read as prose.
 * A span opens with a run of backticks and closes with a run of the same
 * length; an unclosed run is kept as text.
 * @param {string} line one line of prose
 * @return {string} the line with each span replaced by a space
 */
export func stripCodeSpans(line as string) {
    def out as string init "";
    def i as int init 0;
    def n as int init len($line);
    while ($i < $n) {
        if ($line[$i..$i + 1] != "`") {
            $out = $out + $line[$i..$i + 1];
            $i = $i + 1;
            continue;
        }
        def runEnd as int init $i;
        while ($runEnd < $n and $line[$runEnd..$runEnd + 1] == "`") {
            $runEnd = $runEnd + 1;
        }
        def width as int init $runEnd - $i;
        def j as int init $runEnd;
        def closeAt as int init -1;
        while ($j < $n) {
            if ($line[$j..$j + 1] != "`") {
                $j = $j + 1;
                continue;
            }
            def k as int init $j;
            while ($k < $n and $line[$k..$k + 1] == "`") {
                $k = $k + 1;
            }
            if ($k - $j == $width) {
                $closeAt = $k;
                break;
            }
            $j = $k;
        }
        if ($closeAt < 0) {
            $out = $out + $line[$i..$runEnd];
            $i = $runEnd;
            continue;
        }
        $out = $out + " ";
        $i = $closeAt;
    }
    return $out;
}

/**
 * Split the body into slides the way cantrip does: a line of three or more
 * dashes outside fenced code separates them, and a slide with no text is
 * dropped.
 * @param {Scan} sc the scanned talk
 * @param {int} from the first body line (0-based, after the front matter)
 * @return {list of Slide} the slides, with their 1-based start lines
 */
export func slides(sc as Scan, from as int) {
    def out as list of Slide;
    def cur as Slide init Slide{line: $from + 1, hasText: false, hasNotes: false, visible: []};
    def inNote as bool init false;
    for (def i in $from..len($sc.lines)) {
        def line as string init $sc.lines[$i];
        if (not $sc.fenced[$i] and regex.matches('^\s*-{3,}\s*$', $line)) {
            if ($cur.hasText) {
                $out[] = $cur;
            }
            $cur = Slide{line: $i + 2, hasText: false, hasNotes: false, visible: []};
            $inNote = false;
            continue;
        }
        if (strings.trim($line) != "") {
            if (not $cur.hasText) {
                $cur.line = $i + 1;
            }
            $cur.hasText = true;
        }
        if ($sc.fenced[$i]) {
            continue;
        }
        def prose as string init stripCodeSpans($line);
        if (strings.contains($prose, "<!-- notes:")) {
            $cur.hasNotes = true;
            $inNote = true;
        }
        if (not $inNote) {
            $cur.visible[] = $prose;
        }
        if ($inNote and strings.contains($prose, "-->")) {
            $inNote = false;
        }
    }
    if ($cur.hasText) {
        $out[] = $cur;
    }
    return $out;
}

# ---------------------------------------------------------------------------
# Links (rule 1)
# ---------------------------------------------------------------------------

# An inline image, an inline link target, a reference definition, an
# autolink, and a bare URL in text. Each kind is removed from the line once
# read, so a URL is reported once.
def const RE_IMAGE as string init '!\[[^\]]*\]\(\s*(<[^>]*>|[^)\s]*)[^)]*\)';
def const RE_LINK as string init '\]\(\s*(<[^>]*>|[^)\s]*)[^)]*\)';
def const RE_REFDEF as string init '^ {0,3}\[[^\]]+\]:\s*(<[^>]*>|\S+)';
def const RE_AUTOLINK as string init '<([A-Za-z][A-Za-z0-9+.-]*:[^\s<>]*)>';
def const RE_BARE as string init
    '(?i)\b([a-z][a-z0-9+.-]*://[^\s<>()\[\]"`]+|www\.[^\s<>()\[\]"`]+|mailto:[^\s<>()\[\]"`]+)';

/** The URLs one regex finds in a line, as references; group 1 is the URL. */
func urlsIn(pattern as string, text as string, line as int, image as bool) {
    def out as list of UrlRef;
    for (def m in regex.findAll($pattern, $text)) {
        def url as string init unangle($m.groups[0]);
        if ($pattern == RE_BARE) {
            $url = regex.replace("[.,;:!?']+$", $url, "");
        }
        $out[] = UrlRef{line: $line, url: $url, image: $image};
    }
    return $out;
}

/**
 * Every URL in the talk outside fenced code and code spans: link and image
 * targets, reference definitions, autolinks, and bare URLs in text.
 * @param {Scan} sc the scanned talk
 * @return {list of UrlRef} in source order
 */
export func findUrls(sc as Scan) {
    def out as list of UrlRef;
    for (def i in 0..len($sc.lines)) {
        if ($sc.fenced[$i]) {
            continue;
        }
        def rest as string init stripCodeSpans($sc.lines[$i]);
        for (def pattern in [RE_IMAGE, RE_LINK, RE_REFDEF, RE_AUTOLINK, RE_BARE]) {
            for (def ref in urlsIn($pattern, $rest, $i + 1, $pattern == RE_IMAGE)) {
                $out[] = $ref;
            }
            $rest = regex.replace($pattern, $rest, " ");
        }
    }
    return $out;
}

/** Drop the angle brackets of a `<url>` link destination. */
func unangle(s as string) {
    if (strings.startsWith($s, "<") and strings.endsWith($s, ">")) {
        return $s[1..len($s) - 1];
    }
    return $s;
}

/**
 * Is this an external URL (a scheme, `//`, or a bare `www.`)?
 * @param {string} url a link target
 * @return {bool} false for a relative path or a `#fragment`
 */
export func isExternal(url as string) {
    if (strings.startsWith($url, "//") or strings.startsWith(strings.lower($url), "www.")) {
        return true;
    }
    return regex.matches('^[A-Za-z][A-Za-z0-9+.-]*:', $url);
}

/**
 * May a talk in namespace `user` link to `url`? Only http(s) URLs on the
 * allowlist at the top of this file pass.
 * @param {string} url an external URL
 * @param {string} user the talk's namespace (its author's GitHub login)
 * @return {bool} true when the URL points into the Jennifer project
 */
export func urlAllowed(url as string, user as string) {
    def u as string init $url;
    if (strings.startsWith(strings.lower($u), "www.")) {
        $u = "https://" + $u;
    }
    def m as list of string init lineMatch('^(?i)(https?)://([^/?#]*)([^?#]*)', $u);
    if (len($m) == 0) {
        return false;
    }
    def host as string init strings.lower($m[2]);
    def where as string init $m[3];
    if ($host == "" or strings.contains($host, "@") or strings.contains($host, ":")) {
        return false;
    }
    if ($host == ALLOWED_DOMAIN or strings.endsWith($host, "." + ALLOWED_DOMAIN)) {
        return true;
    }
    if ($host != "github.com" and $host != "www.github.com") {
        return false;
    }
    def parts as list of string;
    for (def p in strings.split($where, "/")) {
        if ($p != "") {
            $parts[] = strings.lower($p);
        }
    }
    if (len($parts) == 0) {
        return false;
    }
    if (lists.contains(GITHUB_OWNERS, $parts[0]) or $parts[0] == $user) {
        return true;
    }
    return lists.contains(GITHUB_PATHS, strings.join($parts, "/"));
}

/** The findings for a local image target: a file inside the talk directory. */
func checkImage(file as string, dir as string, ref as UrlRef) {
    def out as list of Finding;
    def target as string init $ref.url;
    def escapes as bool init lists.contains(strings.split($target, "/"), "..");
    if ($target == "" or strings.startsWith($target, "/") or strings.contains($target, "\\") or
        $escapes) {
        $out[] = finding($file, $ref.line, "links", "image \"{$target}\" " + MSG_IMAGE_PATH);
        return $out;
    }
    def p as string init path.join($dir, $target);
    if (not fs.isFile($p)) {
        $out[] = finding(
            $file,
            $ref.line,
            "links",
            "image \"{$target}\" is not a file in the talk directory");
        return $out;
    }
    if (not isInside(fs.realpath($dir), fs.realpath($p))) {
        $out[] = finding(
            $file,
            $ref.line,
            "links",
            "image \"{$target}\" leads out of the talk directory");
    }
    return $out;
}

/** The findings for every URL in a talk (rule 1). */
func checkLinks(file as string, dir as string, user as string, sc as Scan) {
    def out as list of Finding;
    for (def ref in findUrls($sc)) {
        if (not isExternal($ref.url) and not $ref.image) {
            continue;
        }
        if (not isExternal($ref.url)) {
            for (def f in checkImage($file, $dir, $ref)) {
                $out[] = $f;
            }
            continue;
        }
        if ($ref.image) {
            $out[] = finding($file, $ref.line, "links", "image {$ref.url} " + MSG_IMAGE_REMOTE);
        } elseif (not urlAllowed($ref.url, $user)) {
            $out[] = finding($file, $ref.line, "links", "external URL {$ref.url}: " + MSG_EXTERNAL);
        }
    }
    return $out;
}

# ---------------------------------------------------------------------------
# Checking a talk (rules 2 to 6)
# ---------------------------------------------------------------------------

def const MSG_IMAGE_PATH as string init "must be a file beside talk.md (no absolute path, no ..)";
def const MSG_IMAGE_REMOTE as string init "must be a local file beside talk.md";
def const MSG_EXTERNAL as string init "link only to the Jennifer project (see CONTRIBUTING.md)";
def const MSG_NO_FRONT as string init
    "the talk must open with a front-matter block between two --- lines";
def const MSG_NOT_PARSING as string init "(a deliberate fragment is marked ```jennifer excerpt)";

/**
 * Check the encoding: UTF-8 without a byte-order mark (rule 6, first half).
 * @param {string} file the file to check
 * @param {bytes} data its contents
 * @return {list of Finding} empty when the encoding is fine
 */
export func checkEncoding(file as string, data as bytes) {
    def out as list of Finding;
    if (len($data) >= 3 and $data[0] == 0xef and $data[1] == 0xbb and $data[2] == 0xbf) {
        $out[] = finding($file, 1, "encoding", "remove the UTF-8 byte-order mark");
    }
    try {
        convert.stringFromBytes("utf-8", $data);
    } catch (e) {
        $out[] = finding($file, 0, "encoding", "not valid UTF-8; save the file as UTF-8");
    }
    return $out;
}

/**
 * Find em-dashes and en-dashes (rule 6, second half).
 * @param {string} file the file the text came from
 * @param {string} text its contents
 * @return {list of Finding} one per dash kind per line
 */
export func checkDashes(file as string, text as string) {
    def out as list of Finding;
    def lines as list of string init strings.split($text, "\n");
    for (def i in 0..len($lines)) {
        if (strings.contains($lines[$i], convert.fromCodepoint(0x2014))) {
            $out[] = finding(
                $file,
                $i + 1,
                "dashes",
                "em-dash (U+2014): use a colon, a comma or parentheses");
        }
        if (strings.contains($lines[$i], convert.fromCodepoint(0x2013))) {
            $out[] = finding($file, $i + 1, "dashes", "en-dash (U+2013): use \"-\" or \"to\"");
        }
    }
    return $out;
}

/** Does the talk's text name the version, e.g. "Jennifer 0.26.0" or "Jennifer **0.26.0"? */
func statesVersion(body as string, v as string) {
    for (def form in ["Jennifer " + $v, "Jennifer **" + $v, "**Jennifer " + $v]) {
        if (strings.contains($body, $form)) {
            return true;
        }
    }
    return false;
}

/** The front-matter findings (rule 2): only presentation keys, theme set. */
func checkFrontMatter(file as string, fm as FrontMatter) {
    def out as list of Finding;
    if (not $fm.found) {
        $out[] = finding($file, 1, "front-matter", MSG_NO_FRONT);
        return $out;
    }
    for (def key in FRONT_REQUIRED) {
        if (not maps.has($fm.values, $key) or $fm.values[$key] == "") {
            $out[] = finding($file, 1, "front-matter", "missing key \"{$key}\"");
        }
    }
    for (def key in maps.keys($fm.values)) {
        def at as int init $fm.lines[$key];
        if (lists.contains(meta.INJECTED, $key)) {
            def why as string init "\"{$key}\" comes from academy.toml; remove it here";
            $out[] = finding($file, $at, "front-matter", $why);
        } elseif (not lists.contains(FRONT_KEYS, $key)) {
            def why as string init "unknown key \"{$key}\"; only theme, ratio, transition";
            $out[] = finding($file, $at, "front-matter", $why);
        }
    }
    return $out;
}

/** The finding when the text does not state the version academy.toml names. */
func checkVersion(file as string, m as meta.Meta, body as string) {
    def out as list of Finding;
    def valid as bool init regex.matches('^[0-9]+\.[0-9]+\.[0-9]+$', $m.jennifer);
    if (not $valid or statesVersion($body, $m.jennifer)) {
        return $out;
    }
    def v as string init $m.jennifer;
    def why as string init "the text must state the version too: \"Based on Jennifer {$v}\"";
    $out[] = finding($file, 0, "version", $why);
    return $out;
}

/**
 * Read and check a talk's academy.toml.
 * @param {string} dir the talk directory
 * @param {string} user the namespace the talk is in
 * @return {meta.Checked} the entry and its problems
 */
export func readMeta(dir as string, user as string) {
    def file as string init path.join($dir, "academy.toml");
    if (not fs.isFile($file)) {
        def m as meta.Meta;
        return meta.Checked{meta: $m, problems: ["missing academy.toml"]};
    }
    return meta.parse(fs.readString($file), $user);
}

/** Does a line link to the GitHub profile matched by `profile`? */
func linksProfile(line as string, profile as string) {
    for (def pattern in [RE_LINK, RE_AUTOLINK, RE_REFDEF]) {
        for (def ref in urlsIn($pattern, $line, 0, false)) {
            if (regex.matches($profile, $ref.url)) {
                return true;
            }
        }
    }
    return false;
}

/** Does a slide name `user`: `@user` as text, or a link to github.com/user? */
func namesUser(slide as Slide, user as string) {
    def at as string init '(?i)(^|[^A-Za-z0-9_.@-])@' + regex.escape($user) + '([^A-Za-z0-9_-]|$)';
    def profile as string init '(?i)^https?://(www\.)?github\.com/' + regex.escape($user) + '/?$';
    for (def line in $slide.visible) {
        if (regex.matches($at, $line) or linksProfile($line, $profile)) {
            return true;
        }
    }
    return false;
}

/** Is this slide an imprint: the heading, then at least one line of real text? */
func isImprint(slide as Slide, lang as string) {
    def headings as list of string init ["## Imprint"];
    if (strings.lower($lang) == "de" or strings.startsWith(strings.lower($lang), "de-")) {
        $headings[] = "## Impressum";
    }
    def headed as bool init false;
    def texts as int init 0;
    for (def line in $slide.visible) {
        def t as string init strings.trim($line);
        if (lists.contains($headings, $t)) {
            $headed = true;
            continue;
        }
        def bare as string init strings.trim(regex.replace('^\s*([-*+]|[0-9]+\.)\s+', $t, ""));
        if ($bare == "" or strings.startsWith($bare, "#")) {
            continue;
        }
        if (regex.matches('^(!?\[[^\]]*\]\([^)]*\)|<[^>]+>)$', $bare)) {
            continue;
        }
        $texts = $texts + 1;
    }
    return $headed and $texts > 0;
}

/** The finding when the talk does not name its responsible author. */
func checkAuthor(file as string, sc as Scan, fm as FrontMatter, user as string, lang as string) {
    def out as list of Finding;
    def all as list of Slide init slides($sc, $fm.bodyStart);
    if (len($all) == 0) {
        return $out;
    }
    if (namesUser($all[0], $user) or isImprint($all[len($all) - 1], $lang)) {
        return $out;
    }
    def why as string init "name the author: put @{$user} on the title slide, " +
        "or end with an \"## Imprint\" slide";
    $out[] = finding(
        $file,
        $all[0].line,
        "author",
        $why + " (see CONTRIBUTING.md, \"Who you are\")");
    return $out;
}

/** The findings for the slides without speaker notes (rule 3). */
func checkNotes(file as string, sc as Scan, from as int) {
    def out as list of Finding;
    def all as list of Slide init slides($sc, $from);
    if (len($all) == 0) {
        $out[] = finding($file, 0, "notes", "the talk has no slides");
    }
    for (def i in 0..len($all)) {
        if (not $all[$i].hasNotes) {
            def why as string init "slide {$i + 1} has no speaker notes (<!-- notes: ... -->)";
            $out[] = finding($file, $all[$i].line, "notes", $why);
        }
    }
    return $out;
}

/**
 * Is this fenced block Jennifer code, and is it an excerpt?
 * @param {string} info the fence's info string
 * @return {string} "" for another language, else "code" or "excerpt"
 */
export func codeKind(info as string) {
    def words as list of string init regex.split('\s+', strings.trim($info));
    if (len($words) == 0 or $words[0] != "jennifer") {
        return "";
    }
    if (lists.contains($words[1..], EXCERPT)) {
        return "excerpt";
    }
    return "code";
}

/** The findings for each `jennifer` block that does not parse (rule 5). */
func checkCode(file as string, sc as Scan, opts as Options) {
    def out as list of Finding;
    def tmp as string init fs.makeTempDir("", "academy-code-");
    defer fs.removeAll($tmp);
    for (def b in $sc.blocks) {
        def kind as string init codeKind($b.info);
        if ($kind == "") {
            continue;
        }
        def src as string init path.join($tmp, "block-" + convert.toString($b.line) + ".j");
        fs.writeString($src, $b.text);
        def mode as string init "ast";
        if ($kind == "excerpt") {
            $mode = "tokens";
        }
        def r as os.Result init os.run([$opts.jennifer, $mode, $src]);
        if ($r.exitCode == 0) {
            continue;
        }
        def why as string init firstLine(strings.replace($r.stderr, $src, "block"));
        if ($kind == "excerpt") {
            $out[] = finding($file, $b.line, "code", "excerpt does not even lex: {$why}");
        } else {
            $out[] = finding(
                $file,
                $b.line,
                "code",
                "jennifer block does not parse: {$why} " + MSG_NOT_PARSING);
        }
    }
    return $out;
}

/** The first non-empty line of a text. */
func firstLine(s as string) {
    for (def line in strings.split($s, "\n")) {
        if (strings.trim($line) != "") {
            return strings.trim($line);
        }
    }
    return "(no message)";
}

/**
 * Write a buildable copy of a talk into `out`: talk.md with the catalogue
 * fields from academy.toml injected into its front matter, and its images.
 * @param {string} dir the talk directory
 * @param {meta.Meta} m its valid catalogue entry
 * @param {string} out the directory to write (created)
 * @return {string} the path of the prepared talk.md
 */
export func prepare(dir as string, m as meta.Meta, out as string) {
    fs.mkdirAll($out);
    def lines as list of string init strings.split(fs.readString(path.join($dir, "talk.md")), "\n");
    def fm as FrontMatter init frontMatter($lines);
    def head as list of string init ["---"];
    for (def line in meta.frontMatterLines($m)) {
        $head[] = $line;
    }
    if ($fm.found) {
        for (def line in $lines[1..$fm.bodyStart - 1]) {
            $head[] = $line;
        }
    }
    $head[] = "---";
    def rest as string init strings.join($lines[$fm.bodyStart..], "\n");
    def text as string init strings.join($head, "\n") + "\n" + $rest;
    def target as string init path.join($out, "talk.md");
    fs.writeString($target, $text);
    for (def name in fs.list($dir)) {
        if (lists.contains(IMAGE_EXTENSIONS, lowerExt($name))) {
            fs.writeBytes(path.join($out, $name), fs.readBytes(path.join($dir, $name)));
        }
    }
    return $target;
}

/** The findings from building the prepared talk with cantrip (rule 4). */
func checkBuild(file as string, dir as string, m as meta.Meta, opts as Options) {
    def out as list of Finding;
    def tmp as string init fs.makeTempDir("", "academy-build-");
    defer fs.removeAll($tmp);
    def prepared as string init prepare($dir, $m, path.join($tmp, "talk"));
    def argv as list of string init [$opts.jennifer, "run", $opts.cantrip, "build", $prepared];
    $argv[] = "--out";
    $argv[] = path.join($tmp, "out");
    def r as os.Result init os.run($argv);
    for (def line in strings.split($r.stderr, "\n")) {
        if (strings.startsWith($line, "cantrip: warning:")) {
            $out[] = finding($file, 0, "build", $line);
        }
    }
    if ($r.exitCode != 0) {
        def why as string init firstLine(strings.replace($r.stderr + $r.stdout, $prepared, $file));
        $out[] = finding($file, 0, "build", "cantrip failed (exit {$r.exitCode}): {$why}");
    }
    return $out;
}

/** The findings for academy.toml: encoding, dashes, and its schema. */
func checkMetaFile(dir as string, user as string) {
    def file as string init path.join($dir, "academy.toml");
    def out as list of Finding;
    if (not fs.isFile($file)) {
        $out[] = finding($file, 0, "academy", "missing academy.toml (see CONTRIBUTING.md)");
        return $out;
    }
    def data as bytes init fs.readBytes($file);
    $out = checkEncoding($file, $data);
    if (len($out) > 0) {
        return $out;
    }
    $out = checkDashes($file, convert.stringFromBytes("utf-8", $data));
    for (def p in readMeta($dir, $user).problems) {
        $out[] = finding($file, 0, "academy", $p);
    }
    return $out;
}

/**
 * Check one talk against every rule that reads its text.
 * @param {string} dir the talk directory, talks/<user>/<topic>
 * @param {string} user the namespace the talk is in
 * @param {Options} opts which slow checks to run, and with what
 * @return {list of Finding} empty when the talk passes
 */
export func checkTalk(dir as string, user as string, opts as Options) {
    def file as string init path.join($dir, "talk.md");
    def out as list of Finding;
    if (not fs.isFile($file)) {
        $out[] = finding($file, 0, "layout", "missing talk.md");
        return $out;
    }
    def data as bytes init fs.readBytes($file);
    $out = checkEncoding($file, $data);
    if (len($out) > 0) {
        return $out;
    }
    def text as string init convert.stringFromBytes("utf-8", $data);
    def lines as list of string init strings.split(strings.replace($text, "\r\n", "\n"), "\n");
    def fm as FrontMatter init frontMatter($lines);
    def sc as Scan init scan($lines);
    def body as string init strings.join($lines[$fm.bodyStart..], "\n");
    def groups as list of list of Finding;
    $groups[] = checkMetaFile($dir, $user);
    def entry as meta.Checked init readMeta($dir, $user);
    $groups[] = checkDashes($file, $text);
    $groups[] = checkFrontMatter($file, $fm);
    $groups[] = checkVersion($file, $entry.meta, $body);
    $groups[] = checkLinks($file, $dir, $user, $sc);
    $groups[] = checkNotes($file, $sc, $fm.bodyStart);
    $groups[] = checkAuthor($file, $sc, $fm, $user, $entry.meta.lang);
    if ($opts.parseCode) {
        $groups[] = checkCode($file, $sc, $opts);
    }
    if ($opts.build and len($entry.problems) == 0) {
        $groups[] = checkBuild($file, $dir, $entry.meta, $opts);
    }
    for (def g in $groups) {
        for (def f in $g) {
            $out[] = $f;
        }
    }
    return $out;
}

/**
 * Format a finding as `file:line: rule: message` (no line when it is 0).
 * @param {Finding} f the finding
 * @return {string} one line for a terminal or a CI log
 */
export func describe(f as Finding) {
    if ($f.line > 0) {
        return "{$f.file}:{$f.line}: {$f.rule}: {$f.message}";
    }
    return "{$f.file}: {$f.rule}: {$f.message}";
}

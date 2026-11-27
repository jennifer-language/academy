# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0
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
use encoding;
use fs;
use io;
use json;
use lists;
use maps;
use os;
use path;
use regex;
use strings;
use toml;

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

/**
 * Single GitHub pages outside those accounts that may be linked. `karpathy` is
 * his profile only, credited by the talks that reimplement his work.
 */
export def const GITHUB_PATHS as list of string init ["topics/grimoire-plugin", "karpathy"];

/** Organisations that can never be a talk's namespace. */
export def const DENIED_NAMESPACES as list of string init ["jennifer-language", "deckyard"];

/** Front-matter keys a talk may set: how it is presented. The rest comes from academy.toml. */
export def const FRONT_KEYS as list of string init ["theme", "mode", "ratio", "transition"];

/** Front-matter keys every talk must set. */
export def const FRONT_REQUIRED as list of string init ["theme"];

/** File extensions a talk directory may hold besides `talk.md`. */
export def const IMAGE_EXTENSIONS as list of string init [".png", ".jpg", ".jpeg", ".gif"];

/**
 * The plugin file a talk may hold beside talk.md: Cantrip's `cantrip.toml`,
 * naming the preprocessors its build runs.
 */
export def const PLUGIN_CONFIG as string init "cantrip.toml";

/**
 * The preprocessors a talk may name in `cantrip.toml`, `[preprocessor.NAME]`.
 * CI installs exactly these (`grimoire-mermaid`, `grimoire-katex`, and what
 * they need), so a talk can draw diagrams and typeset maths and run nothing
 * else.
 */
export def const PLUGINS as list of string init ["mermaid", "katex"];

/**
 * Keys a talk's plugin table may not set: they choose the program that runs,
 * and in CI that has to be the plugin CI installed. `command` and `args` pick
 * the plugin; `program` is the renderer each plugin runs (`merman-cli`,
 * `katex`).
 */
export def const PLUGIN_RESERVED as list of string init ["command", "args", "program"];

/**
 * The first Cantrip release that runs preprocessors. A Cantrip before it
 * ignores `cantrip.toml` and would publish a `mermaid` fence as code.
 */
export def const PLUGIN_CANTRIP as string init "0.6.0";

/** The most slides a talk may have (rule 11); 15 to 20 is the aim. */
export def const MAX_SLIDES as int init 25;

/** The fewest words of speaker notes a slide needs; a closing imprint is exempt (rule 3). */
export def const MIN_NOTE_WORDS as int init 40;

/** The word in a fence's info string that marks a block as an excerpt. */
export def const EXCERPT as string init "excerpt";

/** The month names a "Rebased on Jennifer X, <Month YYYY>" line may use, January first. */
export def const MONTHS as list of string init [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
];

# ---------------------------------------------------------------------------
# The code folder (rule 12): a talk's runnable programs in `code/`. These
# lists are the one place its rules are defined; CONTRIBUTING.md documents
# them.
# ---------------------------------------------------------------------------

/** The one subdirectory a talk may have: its programs. */
export def const CODE_DIR as string init "code";

/** The file every code folder starts with: what each program shows and how to run it. */
export def const CODE_README as string init "README.md";

/** The licence file every code folder carries: the sample code is MIT-0. */
export def const CODE_LICENSE as string init "LICENSE";

/** The SPDX id of the one licence code/ accepts. */
export def const CODE_LICENSE_ID as string init "MIT-0";

/** The first line of the MIT-0 licence text. */
export def const MIT0_TITLE as string init "MIT No Attribution";

/** The MIT-0 licence text after its copyright line, compared word for word. */
export def const MIT0_BODY as string init
    'Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
';

/** Text file extensions a code folder may hold (`.inc.j` is a `.j`). */
export def const CODE_TEXT_EXTENSIONS as list of string init [
    ".j",
    ".sh",
    ".py",
    ".json",
    ".toml",
    ".yml",
    ".yaml",
    ".csv",
    ".txt",
    ".xml",
    ".ics",
    ".vcf",
    ".sql",
    ".conf",
    ".md",
    ".ini",
    ".tsv",
    ".fasta",
    ".fastq",
    ".tmpl",
    ".css",
    ".ldif",
    ".rb"
];

/** Directory names a code folder never holds: dependencies and build output. */
export def const CODE_FORBIDDEN_DIRS as list of string init ["vendor", "out", "build"];

/** Extensions of build output and logs, refused with their own message. */
export def const CODE_OUTPUT_EXTENSIONS as list of string init [".pdf", ".html", ".htm", ".log"];

/** Extensions of private keys and certificates, refused with their own message. */
export def const CODE_KEY_EXTENSIONS as list of string init [
    ".pem",
    ".key",
    ".crt",
    ".p12",
    ".pfx"
];

/** How deep a file may sit below code/: `code/app/.github/workflows/ci.yml` is depth 4. */
export def const MAX_CODE_DEPTH as int init 4;

/** The one hidden directory a code folder may hold: an example app's CI. */
export def const CODE_HIDDEN_DIR as string init ".github";

/**
 * The directory whose files may have no extension: launchers, text files
 * whose first line is `#!`.
 */
export def const CODE_LAUNCHER_DIR as string init "bin";

/** The largest file a code folder may hold, in bytes (256 KiB). */
export def const MAX_CODE_FILE_BYTES as int init 262144;

/** The most a whole code folder may hold, in bytes (2 MiB). */
export def const MAX_CODE_BYTES as int init 2097152;

/**
 * Text no file in a code folder may contain, each with why: a scratch path
 * from the machine it was written on, and private keys and tokens. A pattern
 * matches one line; a match that contains "EXAMPLE" (AWS's documented
 * placeholder key) is allowed.
 */
export def const CODE_FORBIDDEN_TEXT as list of list of string init [
    ['/tmp/claude-', "an absolute scratch path; paths in programs are relative to code/"],
    ['-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY( BLOCK)?-----', "a private key"],
    ['\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}', "a GitHub token"],
    ['\bgithub_pat_[A-Za-z0-9_]{30,}', "a GitHub token"],
    ['\bxox[abprs]-[A-Za-z0-9-]{10,}', "a Slack token"],
    ['\b(AKIA|ASIA)[0-9A-Z]{16}\b', "an AWS access key"]
];

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
def const MSG_NO_TALK as string init
    "a talk directory holds its talk: talk.md, or talk.<lang>.md per language";
def const MSG_BOTH_FORMS as string init
    "talk.md and talk.<lang>.md together: use talk.md for one language, talk.<lang>.md for several";
def const MSG_NO_META as string init "a talk directory holds its catalogue entry, academy.toml";
def const MSG_SUBDIR as string init
    "the only subdirectory of a talk is code/; keep its images beside talk.md";
def const MSG_OTHER_FILE as string init
    "a talk directory holds its talk files, academy.toml, cantrip.toml, images (.png, .jpg, " +
    ".jpeg, .gif) " +
    "and code/ only";
def const MSG_CODE_EXT as string init
    "is not a file type code/ may hold (see CONTRIBUTING.md, \"The code folder\")";

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

/**
 * A slide: the line it starts on, whether it has text, whether it has notes
 * and how many words they hold, and its visible lines.
 */
export def struct Slide {
    line as int,
    hasText as bool,
    hasNotes as bool,
    noteWords as int,
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

/** Is this file name an image a talk may hold? */
func isImage(name as string) {
    return lists.contains(IMAGE_EXTENSIONS, lowerExt($name));
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

/**
 * The language a file name gives a talk file: "" for `talk.md`, the code for
 * `talk.<code>.md` (valid or not), "-" for a file that is not a talk file.
 * @param {string} name a file name
 * @return {string} "", the code, or "-"
 */
export func talkFileLang(name as string) {
    if ($name == "talk.md") {
        return "";
    }
    def m as list of string init lineMatch('^talk\.([^/]+)\.md$', $name);
    if (len($m) == 0) {
        return "-";
    }
    return $m[1];
}

/** Is this a valid language code for a `talk.<lang>.md` name: ISO 639-1, lower case? */
export func isTalkLang(code as string) {
    return lists.contains(meta.ISO_CODES, $code);
}

/**
 * The talk files of a directory, `talk.md` or `talk.<lang>.md` with a valid
 * code, sorted.
 * @param {string} dir the talk directory
 * @return {list of string} file names
 */
export func talkFiles(dir as string) {
    def out as list of string;
    for (def name in fs.list($dir)) {
        def lang as string init talkFileLang($name);
        if ($lang == "" or isTalkLang($lang)) {
            $out[] = $name;
        }
    }
    return $out;
}

/** The findings for what a single talk directory holds. */
func checkTalkDir(dir as string) {
    def out as list of Finding;
    def real as string init fs.realpath($dir);
    def single as bool init false;
    def perLang as bool init false;
    if (not fs.isFile(path.join($dir, "academy.toml"))) {
        $out[] = finding($dir, 0, "layout", MSG_NO_META);
    }
    for (def name in fs.list($dir)) {
        def p as string init path.join($dir, $name);
        if (fs.realpath($p) != path.join($real, $name)) {
            $out[] = finding($p, 0, "layout", "no symbolic links in a talk");
            continue;
        }
        if (fs.isDir($p)) {
            if ($name != CODE_DIR) {
                $out[] = finding($p, 0, "layout", MSG_SUBDIR);
            }
            continue;
        }
        def lang as string init talkFileLang($name);
        if ($lang == "") {
            $single = true;
        } elseif ($lang != "-" and isTalkLang($lang)) {
            $perLang = true;
        } elseif ($lang != "-") {
            def why as string init "\"{$lang}\" is not an ISO 639-1 code (e.g. talk.de.md)";
            $out[] = finding($p, 0, "layout", $why);
        } elseif ($name != "academy.toml" and $name != PLUGIN_CONFIG and not isImage($name)) {
            $out[] = finding($p, 0, "layout", MSG_OTHER_FILE);
        }
    }
    if (not $single and not $perLang) {
        $out[] = finding($dir, 0, "layout", MSG_NO_TALK);
    }
    if ($single and $perLang) {
        $out[] = finding($dir, 0, "layout", MSG_BOTH_FORMS);
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
        def key as string init strings.lower(strings.trim($line[..$colon]));
        def raw as string init $line[$colon + 1..len($line)];
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
    def cur as Slide init Slide{
        line: $from + 1,
        hasText: false,
        hasNotes: false,
        noteWords: 0,
        visible: []
    };
    def inNote as bool init false;
    for (def i in $from..len($sc.lines)) {
        def line as string init $sc.lines[$i];
        if (not $sc.fenced[$i] and regex.matches('^\s*-{3,}\s*$', $line)) {
            if ($cur.hasText) {
                $out[] = $cur;
            }
            $cur = Slide{line: $i + 2, hasText: false, hasNotes: false, noteWords: 0, visible: []};
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
        if ($inNote) {
            $cur.noteWords = $cur.noteWords + noteWords($prose);
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

/**
 * The words of speaker notes on one line: the text after `<!-- notes:` (when
 * the line opens them) and before `-->` (when it closes them).
 * @param {string} line a line inside or opening a notes comment
 * @return {int} the number of words
 */
export func noteWords(line as string) {
    def t as string init $line;
    def at as int init strings.indexOf($t, "<!-- notes:");
    if ($at >= 0) {
        $t = $t[$at + len("<!-- notes:")..len($t)];
    }
    def end as int init strings.indexOf($t, "-->");
    if ($end >= 0) {
        $t = $t[..$end];
    }
    def n as int init 0;
    for (def w in regex.split('\s+', strings.trim($t))) {
        if ($w != "") {
            $n = $n + 1;
        }
    }
    return $n;
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

/**
 * Is this an http(s) URL on the reader's own machine (`localhost`,
 * `127.0.0.1`, `[::1]`), as a code folder's README names its servers?
 */
export func isLoopback(url as string) {
    def host as string init '(localhost|127\.0\.0\.1|\[::1\])';
    return regex.matches('^(?i)https?://' + $host + '(:[0-9]+)?([/?#].*)?$', $url);
}

/**
 * The findings for every URL in a talk (rule 1). With `loopback`, as in a
 * code folder's README, a link to the reader's own machine is allowed too.
 */
func checkLinks(file as string, dir as string, user as string, sc as Scan, loopback as bool) {
    def out as list of Finding;
    for (def ref in findUrls($sc)) {
        if (not isExternal($ref.url) and not $ref.image) {
            continue;
        }
        if ($loopback and not $ref.image and isLoopback($ref.url)) {
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
        encoding.decode("utf-8", $data);
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

# The characters cantrip's PDF can show: the standard PDF fonts are encoded in
# Windows-1252, so anything else prints as "?". Tab, newline, carriage return,
# printable ASCII, Latin-1 above U+00A0, and the 27 cp1252 extras in 0x80..0x9F.
def const RE_NOT_CP1252 as string init '[^\t\n\r\x{20}-\x{7e}\x{a0}-\x{ff}' +
    '\x{20ac}\x{201a}\x{0192}\x{201e}\x{2026}\x{2020}\x{2021}\x{02c6}\x{2030}\x{0160}' +
    '\x{2039}\x{0152}\x{017d}\x{2018}\x{2019}\x{201c}\x{201d}\x{2022}\x{2013}\x{2014}' +
    '\x{02dc}\x{2122}\x{0161}\x{203a}\x{0153}\x{017e}\x{0178}]';

/**
 * Find characters the PDF cannot show: anything outside Windows-1252, in
 * text, notes and code alike. One finding per character per line.
 * @param {string} file the file the text came from
 * @param {string} text its contents
 * @return {list of Finding} empty when every character can be shown
 */
export func checkCharset(file as string, text as string) {
    def out as list of Finding;
    def lines as list of string init strings.split($text, "\n");
    for (def i in 0..len($lines)) {
        def seen as list of string;
        for (def m in regex.findAll(RE_NOT_CP1252, $lines[$i])) {
            if (lists.contains($seen, $m.text)) {
                continue;
            }
            $seen[] = $m.text;
            def code as string init strings.upper(io.sprintf(
                "%d|base=16",
                convert.toCodepoint($m.text)));
            while (len($code) < 4) {
                $code = "0" + $code;
            }
            def why as string init "U+{$code} \"{$m.text}\" cannot be shown in the PDF; " +
                "write it out (e.g. \"->\" or \"gives\")";
            $out[] = finding($file, $i + 1, "charset", $why);
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
        if ($key == "notes") {
            def why as string init "\"notes\" is set by the academy: talks open with notes shown";
            $out[] = finding($file, $at, "front-matter", $why);
        } elseif (lists.contains(meta.INJECTED, $key)) {
            def why as string init "\"{$key}\" comes from academy.toml; remove it here";
            $out[] = finding($file, $at, "front-matter", $why);
        } elseif (not lists.contains(FRONT_KEYS, $key)) {
            def why as string init "unknown key \"{$key}\"; only theme, mode, ratio, transition";
            $out[] = finding($file, $at, "front-matter", $why);
        }
    }
    return $out;
}

/**
 * The problems of each "Rebased on Jennifer X" line in `body`: it must end in
 * the month of the rebase, ", <Month> <YYYY>", not before the talk's `date`.
 */
func rebaseProblems(body as string, date as string) {
    def out as list of string;
    def pattern as string init '(?m)Rebased on (?:\*\*)?Jennifer (?:\*\*)?[0-9]+\.[0-9]+\.[0-9]+' +
        '[^\n]*?(?:, ([A-Za-z]+) ([0-9]{4}))?$';
    for (def m in regex.findAll($pattern, $body)) {
        def name as string init $m.groups[0];
        if ($name == "") {
            $out[] = "\"Rebased on Jennifer X\" must end in the month of the rebase, " +
                "e.g. \", December 2026\"";
        } elseif (not lists.contains(MONTHS, $name)) {
            $out[] = "\"{$name}\" in \"Rebased on\" is not a month name, e.g. \"December\"";
        } else {
            def number as int init lists.indexOf(MONTHS, $name) + 1;
            def month as string init $m.groups[1] + "-" + convert.toString($number);
            if ($number < 10) {
                $month = $m.groups[1] + "-0" + convert.toString($number);
            }
            if ($month < $date) {
                $out[] = "the rebase ({$month}) is before the talk's date ({$date})";
            }
        }
    }
    return $out;
}

/**
 * The findings when the text does not state the version academy.toml names
 * ("Based on Jennifer X", or "Rebased on Jennifer X, <Month YYYY>" after an
 * update), or a rebase line does not name a valid month.
 */
func checkVersion(file as string, m as meta.Meta, body as string) {
    def out as list of Finding;
    def valid as bool init regex.matches('^[0-9]+\.[0-9]+\.[0-9]+$', $m.jennifer);
    if (not $valid) {
        return $out;
    }
    def v as string init $m.jennifer;
    if (not statesVersion($body, $v)) {
        def why as string init "the text must state the version too: \"Based on Jennifer {$v}\" " +
            "(\"Rebased on Jennifer {$v}, <Month YYYY>\" after an update)";
        $out[] = finding($file, 0, "version", $why);
    }
    for (def why in rebaseProblems($body, $m.date)) {
        $out[] = finding($file, 0, "version", $why);
    }
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

/**
 * The findings for the slides without enough speaker notes (rule 3): every
 * slide needs notes of at least MIN_NOTE_WORDS words, except a closing
 * imprint, which needs notes of any length.
 */
func checkNotes(file as string, sc as Scan, from as int, lang as string) {
    def out as list of Finding;
    def all as list of Slide init slides($sc, $from);
    if (len($all) == 0) {
        $out[] = finding($file, 0, "notes", "the talk has no slides");
    }
    for (def i in 0..len($all)) {
        def s as Slide init $all[$i];
        if (not $s.hasNotes) {
            def why as string init "slide {$i + 1} has no speaker notes (<!-- notes: ... -->)";
            $out[] = finding($file, $s.line, "notes", $why);
            continue;
        }
        def imprint as bool init $i == len($all) - 1 and isImprint($s, $lang);
        if ($s.noteWords < MIN_NOTE_WORDS and not $imprint) {
            def why as string init "slide {$i + 1} has {$s.noteWords} words of speaker notes; " +
                "write at least {MIN_NOTE_WORDS}: what you would say, not the slide again";
            $out[] = finding($file, $s.line, "notes", $why);
        }
    }
    return $out;
}

/** The finding when the talk has more than MAX_SLIDES slides (rule 11). */
func checkLength(file as string, sc as Scan, from as int) {
    def out as list of Finding;
    def all as list of Slide init slides($sc, $from);
    if (len($all) > MAX_SLIDES) {
        def count as int init len($all);
        def why as string init "the talk has {$count} slides; at most {MAX_SLIDES}, " +
            "so split it into two talks";
        $out[] = finding($file, $all[MAX_SLIDES].line, "length", $why);
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
 * The source file of a language version: `talk.md` when the talk has one,
 * else `talk.<lang>.md`.
 * @param {string} dir the talk directory
 * @param {string} lang the version's language
 * @return {string} the path
 */
export func sourceFile(dir as string, lang as string) {
    def single as string init path.join($dir, "talk.md");
    if (fs.isFile($single)) {
        return $single;
    }
    return path.join($dir, "talk." + $lang + ".md");
}

/**
 * Write a buildable copy of one language version into `out`: its talk file
 * as talk.md, with the catalogue fields from academy.toml injected into its
 * front matter, the talk's images, and its `cantrip.toml` if it has one.
 * @param {string} dir the talk directory
 * @param {meta.Meta} m its valid catalogue entry
 * @param {meta.Version} v the version to prepare
 * @param {string} out the directory to write (created)
 * @return {string} the path of the prepared talk.md
 */
export func prepare(dir as string, m as meta.Meta, v as meta.Version, out as string) {
    fs.mkdirAll($out);
    def lines as list of string init strings.split(fs.readString(sourceFile($dir, $v.lang)), "\n");
    def fm as FrontMatter init frontMatter($lines);
    def head as list of string init ["---"];
    for (def line in meta.frontMatterLines($m, $v)) {
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
        if (lists.contains(IMAGE_EXTENSIONS, lowerExt($name)) or $name == PLUGIN_CONFIG) {
            fs.writeBytes(path.join($out, $name), fs.readBytes(path.join($dir, $name)));
        }
    }
    return $target;
}

/** The findings from building the prepared talk with cantrip (rule 4). */
func checkBuild(file as string, dir as string, m as meta.Meta, v as meta.Version, opts as Options) {
    def out as list of Finding;
    def tmp as string init fs.makeTempDir("", "academy-build-");
    defer fs.removeAll($tmp);
    def prepared as string init prepare($dir, $m, $v, path.join($tmp, "talk"));
    if (fs.isFile(path.join($dir, PLUGIN_CONFIG))) {
        def missing as list of Finding init checkPluginsInstalled($file, $prepared, $opts);
        if (len($missing) > 0) {
            return $missing;
        }
    }
    def argv as list of string init [$opts.jennifer, "run", $opts.cantrip, "build", $prepared];
    $argv[] = "--out";
    $argv[] = path.join($tmp, "out");
    def r as os.Result init os.run($argv);
    for (def line in strings.split($r.stderr, "\n")) {
        if (strings.startsWith($line, "cantrip: warning:") and not isPluginNotice($line)) {
            $out[] = finding($file, 0, "build", $line);
        }
    }
    if ($r.exitCode != 0) {
        def why as string init firstLine(strings.replace($r.stderr + $r.stdout, $prepared, $file));
        $out[] = finding($file, 0, "build", "cantrip failed (exit {$r.exitCode}): {$why}");
    }
    return $out;
}

/**
 * Whether a Cantrip warning is only the notice that an allowlisted plugin came
 * from PATH. In CI that is where the plugins are installed, so it is no fault
 * of the talk; any other warning still fails rule 4.
 * @param {string} line one line of Cantrip's standard error
 * @return {bool} true for that notice
 */
export func isPluginNotice(line as string) {
    for (def name in PLUGINS) {
        if (strings.startsWith($line, "cantrip: warning: preprocessor " + $name + ": runs ") and
            strings.endsWith($line, ", found on PATH rather than in this deck")) {
            return true;
        }
    }
    return false;
}

/**
 * The finding for a plugin `cantrip plugins` did not find, from its line
 * (`preprocessor  mermaid  ->  cantrip-mermaid  (not found)`).
 * @param {string} line one line of `cantrip plugins`
 * @return {string} the message
 */
export func pluginMissing(line as string) {
    def name as string init "";
    for (def word in strings.split(strings.trim($line), " ")) {
        if ($word != "" and $word != "preprocessor") {
            $name = $word;
            break;
        }
    }
    return "plugin \"" + $name + "\" is not installed: Cantrip found neither cantrip-" + $name +
        " nor grimoire-" + $name + " on PATH (see CONTRIBUTING.md, \"Diagrams and maths\")";
}

# checkPluginsInstalled asks cantrip what the prepared talk would run. A cantrip
# without the `plugins` verb predates plugins and would ignore cantrip.toml; a
# plugin it does not find would stop the build with a less helpful message.
func checkPluginsInstalled(file as string, prepared as string, opts as Options) {
    def out as list of Finding;
    def r as os.Result init os.run([$opts.jennifer, "run", $opts.cantrip, "plugins", $prepared]);
    if ($r.exitCode != 0) {
        $out[] = finding(
            $file,
            0,
            "build",
            "this talk names plugins in cantrip.toml, which needs Cantrip " + PLUGIN_CANTRIP +
                " or later; " + $opts.cantrip + " does not run them");
        return $out;
    }
    for (def line in strings.split($r.stdout, "\n")) {
        if (strings.endsWith($line, "(not found)")) {
            $out[] = finding($file, 0, "build", pluginMissing($line));
        }
    }
    return $out;
}

/**
 * The findings for a talk's `cantrip.toml` (rule 13): UTF-8, no dashes, valid
 * TOML holding only `[preprocessor.NAME]` tables, each NAME one of `PLUGINS`,
 * and none setting a key of `PLUGIN_RESERVED`. The plugins check their own
 * settings when the talk is built.
 * @param {string} dir the talk directory
 * @return {list of Finding} empty when the file is absent or passes
 */
export func checkPlugins(dir as string) {
    def file as string init path.join($dir, PLUGIN_CONFIG);
    def out as list of Finding;
    if (not fs.isFile($file)) {
        return $out;
    }
    def data as bytes init fs.readBytes($file);
    $out = checkEncoding($file, $data);
    if (len($out) > 0) {
        return $out;
    }
    def text as string init encoding.decode("utf-8", $data);
    $out = checkDashes($file, $text);
    def doc as toml.Value init toml.decode("");
    try {
        $doc = toml.decode($text);
    } catch (e) {
        $out[] = finding($file, 0, "plugins", "not valid TOML: " + $e.message);
        return $out;
    }
    for (def key in toml.keys($doc, "")) {
        if ($key != "preprocessor" or toml.typeOf($doc, "/preprocessor") != "map") {
            $out[] = finding(
                $file,
                0,
                "plugins",
                "\"" + $key + "\": the file holds [preprocessor.NAME] tables only");
        }
    }
    if (len($out) > 0 or not toml.has($doc, "/preprocessor")) {
        return $out;
    }
    for (def name in toml.keys($doc, "/preprocessor")) {
        for (def f in checkPluginTable($file, $doc, $name)) {
            $out[] = $f;
        }
    }
    return $out;
}

# checkPluginTable checks one [preprocessor.NAME] table.
func checkPluginTable(file as string, doc as toml.Value, name as string) {
    def out as list of Finding;
    if (not lists.contains(PLUGINS, $name)) {
        $out[] = finding(
            $file,
            0,
            "plugins",
            "preprocessor \"" + $name + "\" is not one a talk may use; use one of: " +
                strings.join(PLUGINS, ", "));
        return $out;
    }
    def ptr as string init "/preprocessor/" + $name;
    if (toml.typeOf($doc, $ptr) != "map") {
        $out[] = finding($file, 0, "plugins", "preprocessor." + $name + " must be a table");
        return $out;
    }
    for (def key in PLUGIN_RESERVED) {
        if (toml.has($doc, $ptr + "/" + $key)) {
            $out[] = finding(
                $file,
                0,
                "plugins",
                "preprocessor." + $name + "." + $key +
                    ": a talk may not choose the program; CI runs the plugin it installed");
        }
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
    $out = checkDashes($file, encoding.decode("utf-8", $data));
    for (def p in readMeta($dir, $user).problems) {
        $out[] = finding($file, 0, "academy", $p);
    }
    return $out;
}

# ---------------------------------------------------------------------------
# The code folder (rule 12)
# ---------------------------------------------------------------------------

/** One entry below a code folder: its path relative to code/, and what it is. */
export def struct CodeEntry {
    rel as string,
    isDir as bool,
    isLink as bool,
    size as int
};

/** The sort key of a code entry: its path. */
func entryKey(e as CodeEntry) {
    return $e.rel;
}

/** Is `p`, at `rel` below the resolved root `real`, a symbolic link (or below one)? */
func isLinked(p as string, real as string, rel as string) {
    try {
        return fs.realpath($p) != path.join($real, $rel);
    } catch (e) {
        return true;
    }
}

/**
 * Every entry below a code folder, sorted by path. A symbolic link is listed,
 * not followed.
 * @param {string} code the code folder
 * @return {list of CodeEntry} files and directories, `rel` relative to it
 */
export func codeEntries(code as string) {
    def out as list of CodeEntry;
    def real as string init fs.realpath($code);
    def pending as list of string init [""];
    while (len($pending) > 0) {
        def rel as string init $pending[len($pending) - 1];
        $pending = $pending[0..len($pending) - 1];
        for (def name in fs.list(path.join($code, $rel))) {
            def sub as string init $name;
            if ($rel != "") {
                $sub = $rel + "/" + $name;
            }
            def p as string init path.join($code, $sub);
            def e as CodeEntry init CodeEntry{rel: $sub, isDir: false, isLink: false, size: 0};
            $e.isLink = isLinked($p, $real, $sub);
            def descend as bool init (not strings.startsWith($name, ".") or
                $name == CODE_HIDDEN_DIR) and not lists.contains(CODE_FORBIDDEN_DIRS, $name);
            $e.isDir = not $e.isLink and fs.isDir($p);
            if ($e.isDir and $descend) {
                $pending[] = $sub;
            } elseif (not $e.isLink and not $e.isDir) {
                $e.size = fs.stat($p).size;
            }
            $out[] = $e;
        }
    }
    return lists.sortBy($out, entryKey);
}

/**
 * The files a code folder publishes: every regular file, sorted by path.
 * @param {string} code the code folder
 * @return {list of CodeEntry} the files only
 */
export func codeFiles(code as string) {
    def out as list of CodeEntry;
    for (def e in codeEntries($code)) {
        if (not $e.isDir and not $e.isLink) {
            $out[] = $e;
        }
    }
    return $out;
}

/** Is this file name a dotenv file, `.env` or `.env.<name>`? */
export func isDotenv(name as string) {
    return $name == ".env" or regex.matches('^\.env\.[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*$', $name);
}

/** Is the file at `rel` below code/ a launcher: no extension, in a `bin/` folder? */
export func isLauncher(rel as string) {
    def parts as list of string init strings.split($rel, "/");
    def name as string init $parts[len($parts) - 1];
    return len($parts) >= 2 and $parts[len($parts) - 2] == CODE_LAUNCHER_DIR and
        not strings.contains($name, ".");
}

/** Is the file at `rel` below code/ text (not an image)? */
export func isCodeText(rel as string) {
    def name as string init path.base($rel);
    return $rel == CODE_LICENSE or isDotenv($name) or isLauncher($rel) or
        lists.contains(CODE_TEXT_EXTENSIONS, lowerExt($name));
}

/** Is this `.j` file a program lint checks, rather than an `.inc.j` include? */
export func isProgram(name as string) {
    return lowerExt($name) == ".j" and not strings.endsWith(strings.lower($name), ".inc.j");
}

/** The findings for one entry's name, place, type and size. */
func checkCodeEntry(p as string, e as CodeEntry) {
    def out as list of Finding;
    def name as string init path.base($e.rel);
    if ($e.isLink) {
        $out[] = finding($p, 0, "code-folder", "no symbolic links in code/");
        return $out;
    }
    def hiddenOk as bool init ($e.isDir and $name == CODE_HIDDEN_DIR) or
        (not $e.isDir and isDotenv($name));
    if (strings.startsWith($name, ".") and not $hiddenOk) {
        def why as string init "no hidden files or directories (.git, ...) but .github/ and " +
            ".env or .env.<name>";
        $out[] = finding($p, 0, "code-folder", $why);
        return $out;
    }
    if ($e.isDir) {
        if ($name == "vendor") {
            def why as string init "no vendor/ in code/: ship the deck.toml, `jvc install` " +
                "recreates it";
            $out[] = finding($p, 0, "code-folder", $why);
        } elseif (lists.contains(CODE_FORBIDDEN_DIRS, $name)) {
            $out[] = finding($p, 0, "code-folder", "no build output (out/, build/) in code/");
        }
        return $out;
    }
    def depth as int init len(strings.split($e.rel, "/"));
    if ($depth > MAX_CODE_DEPTH) {
        def why as string init "lies {$depth} levels below code/; at most {MAX_CODE_DEPTH} " +
            "(code/a/b/c/file)";
        $out[] = finding($p, 0, "code-folder", $why);
    }
    def ext as string init lowerExt($name);
    if (lists.contains(CODE_KEY_EXTENSIONS, $ext)) {
        def why as string init "no private keys or certificates (.pem, .key, .crt, .p12, .pfx) " +
            "in code/; a program that needs one creates it";
        $out[] = finding($p, 0, "code-folder", $why);
    } elseif (lists.contains(CODE_OUTPUT_EXTENSIONS, $ext)) {
        def why as string init "no build output or logs (.pdf, .html, .log) in code/";
        $out[] = finding($p, 0, "code-folder", $why);
    } elseif (not isCodeText($e.rel) and not isImage($name)) {
        $out[] = finding($p, 0, "code-folder", "\"{$name}\" " + MSG_CODE_EXT);
    }
    if ($e.size > MAX_CODE_FILE_BYTES) {
        def why as string init "is {$e.size} bytes; a file in code/ holds at most " +
            "{MAX_CODE_FILE_BYTES} (256 KiB)";
        $out[] = finding($p, 0, "code-folder", $why);
    }
    return $out;
}

/**
 * What is wrong with a code/LICENSE, "" when it is the MIT-0 licence: its title,
 * a `Copyright <year> <holder>` line, then the MIT-0 text word for word (line
 * breaks and spacing may differ).
 * @param {string} text the file's contents
 * @return {string} the problem, or ""
 */
export func mit0Problem(text as string) {
    def lines as list of string;
    for (def l in strings.split($text, "\n")) {
        if (strings.trim($l) != "") {
            $lines[] = strings.trim($l);
        }
    }
    if (len($lines) < 3 or $lines[0] != MIT0_TITLE) {
        return "must be the MIT-0 licence, starting with \"" + MIT0_TITLE + "\"";
    }
    if (not regex.matches('^Copyright (\(c\) )?[0-9]{4}(-[0-9]{4})?,? \S.*$', $lines[1])) {
        return "line 2 must be \"Copyright <year> <holder>\", got \"" + $lines[1] + "\"";
    }
    def rest as list of string init $lines[2..len($lines)];
    if (words(strings.join($rest, " ")) != words(MIT0_BODY)) {
        return "the text after the copyright line is not the MIT-0 licence word for word";
    }
    return "";
}

/** The whitespace-separated words of a text, joined by single spaces. */
func words(text as string) {
    def out as list of string;
    for (def w in regex.split('\s+', strings.trim($text))) {
        if ($w != "") {
            $out[] = $w;
        }
    }
    return strings.join($out, " ");
}

/** The findings for text no code file may contain (CODE_FORBIDDEN_TEXT). */
func checkForbiddenText(file as string, lines as list of string) {
    def out as list of Finding;
    for (def i in 0..len($lines)) {
        for (def rule in CODE_FORBIDDEN_TEXT) {
            def m as regex.Match init regex.find($rule[0], $lines[$i]);
            if ($m.start >= 0 and not strings.contains($m.text, "EXAMPLE")) {
                $out[] = finding($file, $i + 1, "code-folder", "contains " + $rule[1]);
            }
        }
    }
    return $out;
}

/**
 * The findings for the `import` and `include` paths of a program: a local
 * file must exist inside code/. A deck (`@scope/deck/`) and a module that
 * ships with Jennifer are not looked for.
 */
func checkImports(file as string, realCode as string, lines as list of string) {
    def out as list of Finding;
    for (def i in 0..len($lines)) {
        def m as list of string init lineMatch('^\s*(import|include)\s+"([^"]*)"', $lines[$i]);
        if (len($m) == 0 or strings.startsWith($m[2], "@")) {
            continue;
        }
        def target as string init $m[2];
        if (strings.startsWith($target, "/")) {
            def why as string init "{$m[1]} \"{$target}\": an absolute path; use one relative " +
                "to the program";
            $out[] = finding($file, $i + 1, "code-folder", $why);
            continue;
        }
        def p as string init path.join(path.dir($file), $target);
        def local as bool init $m[1] == "include" or strings.startsWith($target, "./") or
            strings.startsWith($target, "../") or fs.exists($p);
        if (not $local) {
            continue;
        }
        if (not fs.isFile($p)) {
            def why as string init "{$m[1]} \"{$target}\" is not a file in code/";
            $out[] = finding($file, $i + 1, "code-folder", $why);
        } elseif (not isInside($realCode, fs.realpath($p))) {
            def why as string init "{$m[1]} \"{$target}\" leads out of code/";
            $out[] = finding($file, $i + 1, "code-folder", $why);
        }
    }
    return $out;
}

/** The findings for one text file's bytes: encoding, dashes, forbidden text, links, imports. */
func checkCodeText(p as string, rel as string, code as string, user as string) {
    def data as bytes init fs.readBytes($p);
    def out as list of Finding init checkEncoding($p, $data);
    if (len($out) > 0) {
        return $out;
    }
    def text as string init encoding.decode("utf-8", $data);
    if (strings.contains($text, convert.fromCodepoint(0))) {
        $out[] = finding($p, 0, "code-folder", "holds NUL bytes: no binaries in code/");
        return $out;
    }
    if (isLauncher($rel) and not strings.startsWith($text, "#!")) {
        def why as string init "a file without an extension in bin/ is a launcher: its first " +
            "line is #!";
        $out[] = finding($p, 1, "code-folder", $why);
    }
    def lines as list of string init strings.split(strings.replace($text, "\r\n", "\n"), "\n");
    def groups as list of list of Finding;
    $groups[] = checkDashes($p, $text);
    $groups[] = checkForbiddenText($p, $lines);
    if ($p == path.join($code, CODE_README)) {
        $groups[] = checkLinks($p, $code, $user, scan($lines), true);
    }
    if (lowerExt($p) == ".j") {
        $groups[] = checkImports($p, fs.realpath($code), $lines);
    }
    for (def g in $groups) {
        for (def f in $g) {
            $out[] = $f;
        }
    }
    return $out;
}

/**
 * The release a lint L302 finding says removed a call ("was removed in
 * 0.28.0"), or "" when the message names none.
 * @param {string} message the finding's message
 * @return {string} the X.Y.Z release, or ""
 */
func removedIn(message as string) {
    def found as list of string init lineMatch('was removed in ([0-9]+\.[0-9]+\.[0-9]+)', $message);
    if (len($found) < 2) {
        return "";
    }
    return $found[1];
}

/**
 * The release a talk is based on (`jennifer` in academy.toml), or "" when the
 * entry has problems or the value is not X.Y.Z.
 * @param {meta.Checked} entry the talk's parsed catalogue entry
 * @return {string} the release, or ""
 */
func pinnedRelease(entry as meta.Checked) {
    if (len($entry.problems) > 0 or
        not regex.matches('^[0-9]+\.[0-9]+\.[0-9]+$', $entry.meta.jennifer)) {
        return "";
    }
    return $entry.meta.jennifer;
}

/**
 * Whether release `a` comes before release `b`, both X.Y.Z.
 * @param {string} a a release
 * @param {string} b a release
 * @return {bool} true when a < b
 */
func releaseBefore(a as string, b as string) {
    def x as list of string init strings.split($a, ".");
    def y as list of string init strings.split($b, ".");
    for (def i in 0..3) {
        def p as int init convert.toInt($x[$i]);
        def q as int init convert.toInt($y[$i]);
        if ($p != $q) {
            return $p < $q;
        }
    }
    return false;
}

/**
 * Lint the programs of a code folder in one run of `jennifer lint`: every
 * warning and error is a finding, info is not. Decks are not installed, and
 * lint needs no vendor/: an `@scope/deck/` import it cannot resolve is not
 * reported, only the calls into it go unchecked. A call removed in a release
 * after the one the talk is based on (`pinned`) is not a finding: the talk
 * shows that release, where the call still exists.
 */
func lintPrograms(programs as list of string, opts as Options, pinned as string) {
    def out as list of Finding;
    def argv as list of string init [$opts.jennifer, "lint", "--format=json"];
    for (def p in $programs) {
        $argv[] = $p;
    }
    def r as os.Result init os.run($argv);
    def doc as json.Value;
    try {
        $doc = json.decode($r.stdout);
    } catch (e) {
        def why as string init firstLine($r.stderr + $r.stdout);
        $out[] = finding($programs[0], 0, "code-lint", "jennifer lint failed: {$why}");
        return $out;
    }
    if (json.typeOf($doc, "") != "list") {
        return $out;
    }
    for (def i in 0..json.length($doc, "")) {
        def at as string init "/" + convert.toString($i);
        if (json.asString($doc, $at + "/severity") == "info") {
            continue;
        }
        if (json.asString($doc, $at + "/id") == "L302" and $pinned != "") {
            def gone as string init removedIn(json.asString($doc, $at + "/message"));
            if ($gone != "" and releaseBefore($pinned, $gone)) {
                continue;
            }
        }
        def why as string init json.asString($doc, $at + "/message") + " [" +
            json.asString($doc, $at + "/id") + "]";
        $out[] = finding(
            json.asString($doc, $at + "/file"),
            json.asInt($doc, $at + "/line"),
            "code-lint",
            $why);
    }
    return $out;
}

/**
 * Check a talk's code folder, when it has one (rule 12): README.md, the file
 * types, names, depth and sizes, each text file's encoding, dashes and
 * forbidden text, README.md's links, local imports, and (with `parseCode`)
 * that every program but an `.inc.j` passes `jennifer lint` without a warning.
 * @param {string} dir the talk directory
 * @param {string} user the namespace the talk is in
 * @param {Options} opts whether to lint, and with which interpreter
 * @return {list of Finding} empty when there is no code folder or it passes
 */
export func checkCodeFolder(dir as string, user as string, opts as Options) {
    return checkCodeFolderFor($dir, $user, $opts, "");
}

/**
 * `checkCodeFolder` for a talk based on Jennifer `pinned` (X.Y.Z, "" for
 * none): lint does not report a call removed in a later release.
 * @param {string} dir the talk directory
 * @param {string} user the namespace the talk is in
 * @param {Options} opts whether to lint, and with which interpreter
 * @param {string} pinned the release the talk is based on, or ""
 * @return {list of Finding} empty when there is no code folder or it passes
 */
export func checkCodeFolderFor(dir as string, user as string, opts as Options, pinned as string) {
    def out as list of Finding;
    def code as string init path.join($dir, CODE_DIR);
    if (not fs.isDir($code) or isLinked($code, fs.realpath($dir), CODE_DIR)) {
        return $out;
    }
    if (not fs.isFile(path.join($code, CODE_README))) {
        def why as string init "code/ needs a README.md: what each program shows, how to run it, " +
            "and the setup it needs";
        $out[] = finding($code, 0, "code-folder", $why);
    }
    def license as string init path.join($code, CODE_LICENSE);
    if (not fs.isFile($license)) {
        def why as string init "code/ needs a LICENSE with the MIT-0 text: the sample code is " +
            CODE_LICENSE_ID + " (see LICENSE-code)";
        $out[] = finding($code, 0, "code-license", $why);
    } else {
        def problem as string init mit0Problem(fs.readString($license));
        if ($problem != "") {
            $out[] = finding($license, 0, "code-license", $problem);
        }
    }
    def total as int init 0;
    def programs as list of string;
    for (def e in codeEntries($code)) {
        def p as string init path.join($code, $e.rel);
        def found as list of Finding init checkCodeEntry($p, $e);
        for (def f in $found) {
            $out[] = $f;
        }
        $total = $total + $e.size;
        if ($e.isDir or $e.isLink or len($found) > 0 or not isCodeText($e.rel)) {
            continue;
        }
        def text as list of Finding init checkCodeText($p, $e.rel, $code, $user);
        for (def f in $text) {
            $out[] = $f;
        }
        if (isProgram($e.rel) and len($text) == 0) {
            $programs[] = $p;
        }
    }
    if ($total > MAX_CODE_BYTES) {
        def why as string init "code/ holds {$total} bytes; at most {MAX_CODE_BYTES} (2 MiB)";
        $out[] = finding($code, 0, "code-folder", $why);
    }
    if ($opts.parseCode and len($programs) > 0) {
        for (def f in lintPrograms($programs, $opts, $pinned)) {
            $out[] = $f;
        }
    }
    return $out;
}

/**
 * The programs of a code folder that import a deck (`@scope/deck/`), which
 * lint checks without the deck's surface since vendor/ is not shipped.
 * @param {string} dir the talk directory
 * @return {list of string} their paths
 */
export func deckPrograms(dir as string) {
    def out as list of string;
    def code as string init path.join($dir, CODE_DIR);
    if (not fs.isDir($code)) {
        return $out;
    }
    for (def e in codeFiles($code)) {
        if (lowerExt($e.rel) != ".j" or $e.size > MAX_CODE_FILE_BYTES) {
            continue;
        }
        def p as string init path.join($code, $e.rel);
        if (regex.matches('(?m)^\s*import\s+"@', fs.readString($p))) {
            $out[] = $p;
        }
    }
    return $out;
}

/** The findings for how talk files and translation tables pair up. */
func checkLanguages(dir as string, m as meta.Meta) {
    def out as list of Finding;
    def files as list of string init talkFiles($dir);
    def toml as string init path.join($dir, "academy.toml");
    if (lists.contains($files, "talk.md")) {
        for (def t in $m.translations) {
            def why as string init "[translations.{$t.lang}] has no talk.{$t.lang}.md; a talk in " +
                "several languages uses talk.<lang>.md files, not talk.md";
            $out[] = finding($toml, 0, "languages", $why);
        }
        return $out;
    }
    if (len($files) == 0 or $m.lang == "") {
        return $out;
    }
    if (not lists.contains($files, "talk." + $m.lang + ".md")) {
        def why as string init "lang is \"{$m.lang}\" but there is no talk.{$m.lang}.md";
        $out[] = finding($toml, 0, "languages", $why);
    }
    def tables as list of string;
    for (def t in $m.translations) {
        $tables[] = $t.lang;
        if (not lists.contains($files, "talk." + $t.lang + ".md")) {
            $out[] = finding(
                $toml,
                0,
                "languages",
                "[translations.{$t.lang}] has no talk.{$t.lang}.md");
        }
    }
    for (def name in $files) {
        def lang as string init talkFileLang($name);
        if ($lang != $m.lang and not lists.contains($tables, $lang)) {
            def why as string init "{$name} has no [translations.{$lang}] table in academy.toml";
            $out[] = finding(path.join($dir, $name), 0, "languages", $why);
        }
    }
    return $out;
}

/** The version of `m` in language `lang`; `found` is false when there is none. */
def struct Found {
    found as bool,
    version as meta.Version
};

/** Look up a language version. */
func versionIn(m as meta.Meta, lang as string) {
    for (def v in meta.versionsOf($m)) {
        if ($v.lang == $lang) {
            return Found{found: true, version: $v};
        }
    }
    def none as meta.Version;
    return Found{found: false, version: $none};
}

/** The findings for one talk file (`talk.md` or `talk.<lang>.md`) in language `lang`. */
func checkFile(
    dir as string,
    name as string,
    lang as string,
    user as string,
    entry as meta.Checked,
    opts as Options) {
    def file as string init path.join($dir, $name);
    def data as bytes init fs.readBytes($file);
    def out as list of Finding init checkEncoding($file, $data);
    if (len($out) > 0) {
        return $out;
    }
    def text as string init encoding.decode("utf-8", $data);
    def lines as list of string init strings.split(strings.replace($text, "\r\n", "\n"), "\n");
    def fm as FrontMatter init frontMatter($lines);
    def sc as Scan init scan($lines);
    def body as string init strings.join($lines[$fm.bodyStart..], "\n");
    def groups as list of list of Finding;
    $groups[] = checkDashes($file, $text);
    $groups[] = checkCharset($file, $text);
    $groups[] = checkFrontMatter($file, $fm);
    $groups[] = checkVersion($file, $entry.meta, $body);
    $groups[] = checkLinks($file, $dir, $user, $sc, false);
    $groups[] = checkNotes($file, $sc, $fm.bodyStart, $lang);
    $groups[] = checkLength($file, $sc, $fm.bodyStart);
    $groups[] = checkAuthor($file, $sc, $fm, $user, $lang);
    if ($opts.parseCode) {
        $groups[] = checkCode($file, $sc, $opts);
    }
    def v as Found init versionIn($entry.meta, $lang);
    if ($opts.build and len($entry.problems) == 0 and $v.found) {
        $groups[] = checkBuild($file, $dir, $entry.meta, $v.version, $opts);
    }
    for (def g in $groups) {
        for (def f in $g) {
            $out[] = $f;
        }
    }
    return $out;
}

/**
 * Check one talk against every rule that reads its text, for every language
 * file it has.
 * @param {string} dir the talk directory, talks/<user>/<topic>
 * @param {string} user the namespace the talk is in
 * @param {Options} opts which slow checks to run, and with what
 * @return {list of Finding} empty when the talk passes
 */
export func checkTalk(dir as string, user as string, opts as Options) {
    def out as list of Finding init checkMetaFile($dir, $user);
    for (def f in checkPlugins($dir)) {
        $out[] = $f;
    }
    def entry as meta.Checked init readMeta($dir, $user);
    for (def f in checkCodeFolderFor($dir, $user, $opts, pinnedRelease($entry))) {
        $out[] = $f;
    }
    def files as list of string init talkFiles($dir);
    if (len($files) == 0) {
        $out[] = finding(path.join($dir, "talk.md"), 0, "layout", "missing talk.md");
        return $out;
    }
    for (def f in checkLanguages($dir, $entry.meta)) {
        $out[] = $f;
    }
    for (def name in $files) {
        def lang as string init talkFileLang($name);
        if ($lang == "") {
            $lang = $entry.meta.lang;
        }
        for (def f in checkFile($dir, $name, $lang, $user, $entry, $opts)) {
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

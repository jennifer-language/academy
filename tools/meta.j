# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * A talk's `academy.toml`: the catalogue entry the gallery is built from.
 *
 * It is the single source of the talk's title, description, author, language,
 * date and tags. `tools/build.sh` injects those into a copy of `talk.md`
 * before cantrip runs (`frontMatterLines`), so authors write them once. The
 * schema is strict: an unknown key, a wrong type or a bad value is a problem.
 * @module meta
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use convert;
use lists;
use regex;
use strings;
use toml;

/** The keys academy.toml may hold. */
export def const KEYS as list of string init [
    "title",
    "description",
    "author",
    "name",
    "license",
    "lang",
    "jennifer",
    "date",
    "updated",
    "level",
    "tags",
];

/** The keys that must be there. */
export def const REQUIRED as list of string init [
    "title",
    "description",
    "author",
    "license",
    "lang",
    "jennifer",
    "date",
    "level",
    "tags",
];

/** The one licence a talk is published under (the contributor declaration's). */
export def const LICENSE as string init "CC-BY-4.0";

/** The levels a talk is written for, easiest first. */
export def const LEVELS as list of string init ["beginner", "intermediate", "advanced"];

export def const MAX_TITLE as int init 80;
export def const MIN_DESCRIPTION as int init 50;
export def const MAX_DESCRIPTION as int init 300;
export def const MAX_NAME as int init 80;
export def const MAX_TAGS as int init 8;
export def const MAX_TAG as int init 24;

/** A talk's catalogue entry. `name` and `updated` are "" when not given. */
export def struct Meta {
    title as string,
    description as string,
    author as string,
    name as string,
    license as string,
    lang as string,
    jennifer as string,
    date as string,
    updated as string,
    level as string,
    tags as list of string
};

/** The parsed entry and what is wrong with it (one message per problem). */
export def struct Checked {
    meta as Meta,
    problems as list of string
};

/** A string key's value, or "" (with a problem) when it is not a string. */
func text(doc as toml.Value, key as string) {
    if (not toml.has($doc, "/" + $key)) {
        return "";
    }
    if (toml.typeOf($doc, "/" + $key) != "string") {
        return "";
    }
    return toml.asString($doc, "/" + $key);
}

/** The problems with the types of the keys present. */
func typeProblems(doc as toml.Value) {
    def out as list of string;
    for (def key in toml.keys($doc, "")) {
        if (not lists.contains(KEYS, $key)) {
            $out[] = "unknown key \"{$key}\"";
            continue;
        }
        def kind as string init toml.typeOf($doc, "/" + $key);
        if ($key == "tags") {
            if ($kind != "list") {
                $out[] = "tags must be a list of strings";
            }
            continue;
        }
        if ($kind != "string") {
            $out[] = "{$key} must be a string, got {$kind}";
        }
    }
    for (def key in REQUIRED) {
        if (not toml.has($doc, "/" + $key)) {
            $out[] = "missing key \"{$key}\"";
        }
    }
    return $out;
}

/** The tags, and a problem for each element that is not a string. */
func tagsOf(doc as toml.Value) {
    def out as list of string;
    if (not toml.has($doc, "/tags") or toml.typeOf($doc, "/tags") != "list") {
        return $out;
    }
    for (def i in 0..toml.length($doc, "/tags")) {
        def at as string init "/tags/" + convert.toString($i);
        if (toml.typeOf($doc, $at) == "string") {
            $out[] = toml.asString($doc, $at);
        } else {
            $out[] = "";
        }
    }
    return $out;
}

/** Is this a month, YYYY-MM? */
func isMonth(s as string) {
    return regex.matches('^[0-9]{4}-(0[1-9]|1[0-2])$', $s);
}

/** Plain text: one line, no control characters, no URL, no Markdown link. */
func plainProblem(key as string, s as string) {
    if (regex.matches('[\x00-\x1f\x7f]', $s)) {
        return "{$key} must be one line of plain text";
    }
    if (regex.matches('(?i)([a-z][a-z0-9+.-]*://|www\.|\]\()', $s)) {
        return "{$key} is plain text: no URLs or links";
    }
    return "";
}

/** The problems with the values (the types are already right). */
func valueProblems(m as Meta, user as string) {
    def out as list of string;
    for (def key in ["title", "description", "name"]) {
        def v as string init $m.title;
        if ($key == "description") {
            $v = $m.description;
        } elseif ($key == "name") {
            $v = $m.name;
        }
        def p as string init plainProblem($key, $v);
        if ($p != "") {
            $out[] = $p;
        }
    }
    if (strings.trim($m.title) == "" or len($m.title) > MAX_TITLE) {
        $out[] = "title must be 1 to {MAX_TITLE} characters";
    }
    def size as int init len($m.description);
    if ($size < MIN_DESCRIPTION or $size > MAX_DESCRIPTION) {
        $out[] = "description is {$size} characters, not {MIN_DESCRIPTION} to {MAX_DESCRIPTION}";
    }
    if (len($m.name) > MAX_NAME) {
        $out[] = "name must be at most {MAX_NAME} characters";
    }
    if ($m.author != $user) {
        $out[] = "author is \"{$m.author}\" but the talk is in the namespace \"{$user}\"";
    }
    if ($m.license != LICENSE) {
        $out[] = "license must be \"{LICENSE}\", got \"{$m.license}\"";
    }
    if (not regex.matches('^[a-z]{2,3}$', $m.lang)) {
        $out[] = "lang must be a primary language tag such as \"en\" or \"de\", got \"{$m.lang}\"";
    }
    if (not regex.matches('^[0-9]+\.[0-9]+\.[0-9]+$', $m.jennifer)) {
        $out[] = "jennifer must be a release version X.Y.Z, got \"{$m.jennifer}\"";
    }
    if (not isMonth($m.date)) {
        $out[] = "date must be YYYY-MM, got \"{$m.date}\"";
    }
    if ($m.updated != "" and not isMonth($m.updated)) {
        $out[] = "updated must be YYYY-MM, got \"{$m.updated}\"";
    } elseif ($m.updated != "" and isMonth($m.date) and $m.updated < $m.date) {
        $out[] = "updated ({$m.updated}) is before date ({$m.date})";
    }
    if (not lists.contains(LEVELS, $m.level)) {
        $out[] = "level must be beginner, intermediate or advanced, got \"{$m.level}\"";
    }
    return $out;
}

/** The problems with the tags. */
func tagProblems(tags as list of string) {
    def out as list of string;
    if (len($tags) < 1 or len($tags) > MAX_TAGS) {
        def n as int init len($tags);
        $out[] = "tags must hold 1 to {MAX_TAGS} tags, got {$n}";
    }
    def seen as list of string;
    for (def t in $tags) {
        if (len($t) > MAX_TAG or not regex.matches('^[a-z0-9]+(-[a-z0-9]+)*$', $t)) {
            $out[] = "tag \"{$t}\": lowercase a-z, 0-9 and single hyphens, at most {MAX_TAG}";
        } elseif (lists.contains($seen, $t)) {
            $out[] = "tag \"{$t}\" is listed twice";
        }
        $seen[] = $t;
    }
    return $out;
}

/**
 * Parse and check an academy.toml.
 * @param {string} source the file's text
 * @param {string} user the namespace the talk is in
 * @return {Checked} the entry, and its problems (empty when it is valid)
 */
export func parse(source as string, user as string) {
    def m as Meta;
    def problems as list of string;
    def doc as toml.Value;
    try {
        $doc = toml.decode($source);
    } catch (e) {
        $problems[] = "not valid TOML: " + $e.message;
        return Checked{meta: $m, problems: $problems};
    }
    $problems = typeProblems($doc);
    $m = Meta{
        title: text($doc, "title"),
        description: text($doc, "description"),
        author: text($doc, "author"),
        name: text($doc, "name"),
        license: text($doc, "license"),
        lang: text($doc, "lang"),
        jennifer: text($doc, "jennifer"),
        date: text($doc, "date"),
        updated: text($doc, "updated"),
        level: text($doc, "level"),
        tags: tagsOf($doc),
    };
    for (def p in valueProblems($m, $user)) {
        $problems[] = $p;
    }
    for (def p in tagProblems($m.tags)) {
        $problems[] = $p;
    }
    return Checked{meta: $m, problems: $problems};
}

/** The keys build.sh injects into talk.md, so talk.md must not set them. */
export def const INJECTED as list of string init [
    "title",
    "description",
    "subject",
    "keywords",
    "lang",
    "author",
    "date",
];

/** Quote a value for cantrip's front matter, which strips one outer pair. */
func quoted(v as string) {
    return "\"" + $v + "\"";
}

/**
 * The front-matter lines injected for cantrip, which writes them into the
 * HTML and PDF metadata.
 * @param {Meta} m a valid entry
 * @return {list of string} `key: "value"` lines, without the `---` fences
 */
export func frontMatterLines(m as Meta) {
    def who as string init "@" + $m.author;
    if ($m.name != "") {
        $who = $m.name + " (@" + $m.author + ")";
    }
    def month as string init $m.date;
    if ($m.updated != "") {
        $month = $m.updated;
    }
    def words as list of string init ["jennifer"];
    for (def t in $m.tags) {
        if (not lists.contains($words, $t)) {
            $words[] = $t;
        }
    }
    return [
        "title: " + quoted($m.title),
        "description: " + quoted($m.description),
        "subject: " + quoted($m.description),
        "keywords: " + quoted(strings.join($words, ", ")),
        "lang: " + quoted($m.lang),
        "author: " + quoted($who),
        "date: " + quoted($month),
    ];
}

/**
 * The month a talk sorts and is dated by: `updated` when given, else `date`.
 * @param {Meta} m an entry
 * @return {string} YYYY-MM
 */
export func latest(m as Meta) {
    if ($m.updated != "") {
        return $m.updated;
    }
    return $m.date;
}

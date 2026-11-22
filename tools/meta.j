# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

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
    "translations",
];

/** The keys a `[translations.<lang>]` table may hold. */
export def const TRANSLATION_KEYS as list of string init ["title", "description", "keywords"];

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

/** The ISO 639-1 language codes (all 183): the languages a talk may be in. */
export def const ISO_CODES as list of string init [
    "aa",
    "ab",
    "ae",
    "af",
    "ak",
    "am",
    "an",
    "ar",
    "as",
    "av",
    "ay",
    "az",
    "ba",
    "be",
    "bg",
    "bi",
    "bm",
    "bn",
    "bo",
    "br",
    "bs",
    "ca",
    "ce",
    "ch",
    "co",
    "cr",
    "cs",
    "cu",
    "cv",
    "cy",
    "da",
    "de",
    "dv",
    "dz",
    "ee",
    "el",
    "en",
    "eo",
    "es",
    "et",
    "eu",
    "fa",
    "ff",
    "fi",
    "fj",
    "fo",
    "fr",
    "fy",
    "ga",
    "gd",
    "gl",
    "gn",
    "gu",
    "gv",
    "ha",
    "he",
    "hi",
    "ho",
    "hr",
    "ht",
    "hu",
    "hy",
    "hz",
    "ia",
    "id",
    "ie",
    "ig",
    "ii",
    "ik",
    "io",
    "is",
    "it",
    "iu",
    "ja",
    "jv",
    "ka",
    "kg",
    "ki",
    "kj",
    "kk",
    "kl",
    "km",
    "kn",
    "ko",
    "kr",
    "ks",
    "ku",
    "kv",
    "kw",
    "ky",
    "la",
    "lb",
    "lg",
    "li",
    "ln",
    "lo",
    "lt",
    "lu",
    "lv",
    "mg",
    "mh",
    "mi",
    "mk",
    "ml",
    "mn",
    "mr",
    "ms",
    "mt",
    "my",
    "na",
    "nb",
    "nd",
    "ne",
    "ng",
    "nl",
    "nn",
    "no",
    "nr",
    "nv",
    "ny",
    "oc",
    "oj",
    "om",
    "or",
    "os",
    "pa",
    "pi",
    "pl",
    "ps",
    "pt",
    "qu",
    "rm",
    "rn",
    "ro",
    "ru",
    "rw",
    "sa",
    "sc",
    "sd",
    "se",
    "sg",
    "si",
    "sk",
    "sl",
    "sm",
    "sn",
    "so",
    "sq",
    "sr",
    "ss",
    "st",
    "su",
    "sv",
    "sw",
    "ta",
    "te",
    "tg",
    "th",
    "ti",
    "tk",
    "tl",
    "tn",
    "to",
    "tr",
    "ts",
    "tt",
    "tw",
    "ty",
    "ug",
    "uk",
    "ur",
    "uz",
    "ve",
    "vi",
    "vo",
    "wa",
    "wo",
    "xh",
    "yi",
    "yo",
    "za",
    "zh",
    "zu",
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
export def const MAX_KEYWORDS as int init 200;

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
    tags as list of string,
    translations as list of Translation
};

/** A further language of a talk: `[translations.<lang>]`. */
export def struct Translation {
    lang as string,
    title as string,
    description as string,
    keywords as string
};

/** One language version of a talk, primary or translated, with its catalogue text. */
export def struct Version {
    lang as string,
    primary as bool,
    title as string,
    description as string,
    keywords as string
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
        if ($key == "translations") {
            if ($kind != "map") {
                $out[] = "translations must be tables, [translations.<lang>]";
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

/** The problems with a title and a description; `prefix` names where they are. */
func textProblems(prefix as string, title as string, description as string) {
    def out as list of string;
    for (def p in [
        plainProblem($prefix + "title", $title),
        plainProblem($prefix + "description", $description)
    ]) {
        if ($p != "") {
            $out[] = $p;
        }
    }
    if (strings.trim($title) == "" or len($title) > MAX_TITLE) {
        $out[] = $prefix + "title must be 1 to {MAX_TITLE} characters";
    }
    def size as int init len($description);
    if ($size < MIN_DESCRIPTION or $size > MAX_DESCRIPTION) {
        $out[] = $prefix +
            "description is {$size} characters, not {MIN_DESCRIPTION} to {MAX_DESCRIPTION}";
    }
    return $out;
}

/** The problems with the values (the types are already right). */
func valueProblems(m as Meta, user as string) {
    def out as list of string init textProblems("", $m.title, $m.description);
    def p as string init plainProblem("name", $m.name);
    if ($p != "") {
        $out[] = $p;
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
    if (not lists.contains(ISO_CODES, $m.lang)) {
        $out[] = "lang must be an ISO 639-1 code such as \"en\" or \"de\", got \"{$m.lang}\"";
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

/** A string in a translation table, or "" when absent or not a string. */
func tableText(doc as toml.Value, at as string, key as string) {
    def ptr as string init $at + "/" + $key;
    if (not toml.has($doc, $ptr) or toml.typeOf($doc, $ptr) != "string") {
        return "";
    }
    return toml.asString($doc, $ptr);
}

/** The problems with one `[translations.<lang>]` table, read at `at`. */
func translationProblems(doc as toml.Value, at as string, t as Translation, primary as string) {
    def out as list of string;
    def name as string init "translations." + $t.lang;
    if (not lists.contains(ISO_CODES, $t.lang)) {
        $out[] = "[{$name}]: \"{$t.lang}\" is not an ISO 639-1 code";
    }
    if ($t.lang == $primary) {
        $out[] = "[{$name}]: {$t.lang} is the primary language; use title and description";
    }
    if (toml.typeOf($doc, $at) != "map") {
        $out[] = "[{$name}] must be a table";
        return $out;
    }
    for (def key in toml.keys($doc, $at)) {
        if (not lists.contains(TRANSLATION_KEYS, $key)) {
            $out[] = "[{$name}]: unknown key \"{$key}\"";
        } elseif (toml.typeOf($doc, $at + "/" + $key) != "string") {
            $out[] = "[{$name}]: {$key} must be a string";
        }
    }
    for (def p in textProblems("[" + $name + "] ", $t.title, $t.description)) {
        $out[] = $p;
    }
    def kw as string init plainProblem("[" + $name + "] keywords", $t.keywords);
    if ($kw != "") {
        $out[] = $kw;
    }
    if (len($t.keywords) > MAX_KEYWORDS) {
        $out[] = "[{$name}]: keywords must be at most {MAX_KEYWORDS} characters";
    }
    return $out;
}

/** The translation tables, in file order, and their problems appended to `problems`. */
func translationsOf(doc as toml.Value, primary as string) {
    def out as list of Translation;
    if (not toml.has($doc, "/translations") or toml.typeOf($doc, "/translations") != "map") {
        return $out;
    }
    for (def lang in toml.keys($doc, "/translations")) {
        def at as string init "/translations/" + $lang;
        $out[] = Translation{
            lang: $lang,
            title: tableText($doc, $at, "title"),
            description: tableText($doc, $at, "description"),
            keywords: tableText($doc, $at, "keywords"),
        };
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
        translations: [],
    };
    $m.translations = translationsOf($doc, $m.lang);
    for (def p in valueProblems($m, $user)) {
        $problems[] = $p;
    }
    for (def t in $m.translations) {
        for (def p in translationProblems($doc, "/translations/" + $t.lang, $t, $m.lang)) {
            $problems[] = $p;
        }
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
    "notes",
];

/** Quote a value for cantrip's front matter, which strips one outer pair. */
func quoted(v as string) {
    return "\"" + $v + "\"";
}

/**
 * Every language version of a talk: the primary language first, then each
 * translation in file order.
 * @param {Meta} m an entry
 * @return {list of Version} at least the primary version
 */
export func versionsOf(m as Meta) {
    def out as list of Version init [
        Version{
            lang: $m.lang,
            primary: true,
            title: $m.title,
            description: $m.description,
            keywords: "",
        }
    ];
    for (def t in $m.translations) {
        $out[] = Version{
            lang: $t.lang,
            primary: false,
            title: $t.title,
            description: $t.description,
            keywords: $t.keywords,
        };
    }
    return $out;
}

/**
 * The front-matter lines injected for cantrip, which writes them into the
 * HTML and PDF metadata: the version's title, description and language, and
 * the talk's author and date.
 * @param {Meta} m a valid entry
 * @param {Version} v the language version being built
 * @return {list of string} `key: "value"` lines, without the `---` fences
 */
export func frontMatterLines(m as Meta, v as Version) {
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
    def keywords as string init strings.join($words, ", ");
    if ($v.keywords != "") {
        $keywords = $v.keywords;
    }
    return [
        "title: " + quoted($v.title),
        "description: " + quoted($v.description),
        "subject: " + quoted($v.description),
        "keywords: " + quoted($keywords),
        "lang: " + quoted($v.lang),
        "author: " + quoted($who),
        "date: " + quoted($month),
        # Every academy talk opens with the speaker notes shown; s hides them.
        "notes: open",
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

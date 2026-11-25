# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * White-box tests for the rules, above all the negative cases: each scratch
 * talk breaks one rule and must be reported with the right rule name.
 * @module rulesTest
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use testing;

/** A talk that passes every rule; each negative case changes one thing. */
def const GOOD as string init '---
theme: plain
---

# A good talk

By @ada. Based on Jennifer 0.26.0. See [the docs](https://docs.jennifer-lang.dev/),
[my repo](https://github.com/ada/demo) and `https://example.com` in code.

```jennifer
def x as int init 6 * 7;
```

<!-- notes: hello ... -->

---

## Second

```text
https://example.com/in-a-fence
---
```

<!-- notes: the dashes in the fence do not split the slide ... -->
';

/** The catalogue entry beside GOOD. */
def const GOOD_META as string init 'title = "A good talk"
description = "A short talk that passes every rule, with a description long enough."
author = "ada"
name = "Ada Example"
license = "CC-BY-4.0"
lang = "en"
jennifer = "0.26.0"
date = "2026-10"
updated = "2026-11"
level = "beginner"
tags = ["basics", "test-talk"]
';

/** The options the fast tests use: no interpreter runs. */
func fast() {
    return Options{jennifer: interpreter(), cantrip: "", parseCode: false, build: false};
}

/** The interpreter to run code blocks with. */
func interpreter() {
    if (os.hasEnv("JENNIFER") and os.getEnv("JENNIFER") != "") {
        return os.getEnv("JENNIFER");
    }
    return "jennifer";
}

/** Write a talk into a fresh tree and return its directory. */
func makeTalk(user as string, topic as string, text as string) {
    return makeTalkWith($user, $topic, $text, GOOD_META);
}

/** Write a talk and its academy.toml into a fresh tree; return its directory. */
func makeTalkWith(user as string, topic as string, text as string, entry as string) {
    def root as string init fs.makeTempDir("", "academy-test-");
    def dir as string init path.join($root, "talks", $user, $topic);
    fs.mkdirAll($dir);
    fs.writeString(path.join($dir, "talk.md"), padNotes($text));
    fs.writeString(path.join($dir, "academy.toml"), $entry);
    return $dir;
}

/**
 * Expand every notes comment ending in ` ... -->` to MIN_NOTE_WORDS more
 * words, so a fixture reads short but passes the notes rule.
 */
func padNotes(text as string) {
    return strings.replace(
        $text,
        " ... -->",
        " " + strings.replicate("word ", MIN_NOTE_WORDS) + "-->");
}

/** Check GOOD with another academy.toml (fast) and return the findings. */
func checkedMeta(entry as string) {
    def dir as string init makeTalkWith("ada", "talk", GOOD, $entry);
    defer fs.removeAll(path.dir(path.dir(path.dir($dir))));
    return checkTalk($dir, "ada", fast());
}

/** The messages of a list of findings, one per line. */
func messagesOf(found as list of Finding) {
    def out as string init "";
    for (def f in $found) {
        $out = $out + describe($f) + "\n";
    }
    return $out;
}

/** The rule names of a list of findings. */
func rulesOf(found as list of Finding) {
    def out as list of string;
    for (def f in $found) {
        $out[] = $f.rule;
    }
    return $out;
}

/** Check a scratch talk (fast) and return its findings. */
func checked(text as string) {
    def dir as string init makeTalk("ada", "talk", $text);
    defer fs.removeAll(path.dir(path.dir(path.dir($dir))));
    return checkTalk($dir, "ada", fast());
}

/** Replace exactly one occurrence, so a test cannot silently change nothing. */
func swap(text as string, old as string, new as string) {
    testing.assertEqual(strings.count($text, $old), 1);
    return strings.replace($text, $old, $new);
}

func testGoodTalkPasses() {
    testing.assertEqual(checked(GOOD), []);
}

func testExternalLinkFails() {
    def found as list of Finding init checked(swap(
        GOOD,
        "https://github.com/ada/demo",
        "https://example.com/x"));
    testing.assertEqual(rulesOf($found), ["links"]);
    testing.assertContains($found[0].message, "https://example.com/x");
    testing.assertEqual($found[0].line, 8);
}

func testBareUrlAndAutolinkFail() {
    def text as string init swap(
        GOOD,
        "<!-- notes: hello ... -->",
        "Visit http://evil.test and <https://evil.test/a>.\n\n<!-- notes: hello ... -->");
    testing.assertEqual(rulesOf(checked($text)), ["links", "links"]);
}

func testRemoteImageFails() {
    testing.assertEqual(
        rulesOf(checked(swap(
            GOOD,
            "# A good talk\n",
            "# A good talk\n\n![x](https://docs.jennifer-lang.dev/a.png)\n"))),
        ["links"]);
}

func testImageOutsideTheTalkFails() {
    testing.assertEqual(
        rulesOf(checked(swap(GOOD, "# A good talk\n", "# A good talk\n\n![x](../other/a.png)\n"))),
        ["links"]);
    testing.assertEqual(
        rulesOf(checked(swap(GOOD, "# A good talk\n", "# A good talk\n\n![x](missing.png)\n"))),
        ["links"]);
}

func testMissingNoteFails() {
    def found as list of Finding init checked(swap(
        GOOD,
        "<!-- notes: the dashes in the fence do not split the slide ... -->",
        ""));
    testing.assertEqual(rulesOf($found), ["notes"]);
    testing.assertContains($found[0].message, "slide 2");
}

func testFrontMatterHoldsOnlyPresentationKeys() {
    testing.assertEqual(
        checked(swap(
            GOOD,
            "theme: plain",
            "theme: plain\nmode: dark\nratio: 4:3\ntransition: zoom")),
        []);
    def dup as list of Finding init checked(swap(
        GOOD,
        "theme: plain",
        "theme: plain\ntitle: Again"));
    testing.assertEqual(rulesOf($dup), ["front-matter"]);
    testing.assertContains($dup[0].message, "comes from academy.toml");
    testing.assertEqual($dup[0].line, 3);
    testing.assertEqual(
        rulesOf(checked(swap(GOOD, "theme: plain", "theme: plain\ngithub: ada"))),
        ["front-matter"]);
    def none as list of Finding init checked(swap(GOOD, "theme: plain", "ratio: 16:9"));
    testing.assertEqual(rulesOf($none), ["front-matter"]);
    testing.assertContains($none[0].message, "missing key \"theme\"");
    # Without the opening line the block is no front matter, so it is a slide (without notes).
    testing.assertEqual(
        rulesOf(checked(swap(GOOD, "---\ntheme", "theme"))),
        ["front-matter", "notes", "author"]);
}

func testMissingAcademyTomlFails() {
    def dir as string init makeTalk("ada", "talk", GOOD);
    defer fs.removeAll(path.dir(path.dir(path.dir($dir))));
    fs.remove(path.join($dir, "academy.toml"));
    def found as list of Finding init checkTalk($dir, "ada", fast());
    testing.assertEqual(rulesOf($found), ["academy"]);
    testing.assertContains($found[0].message, "missing academy.toml");
    testing.assertContains(messagesOf(checkLayout(path.dir(path.dir($dir)))), "academy.toml");
}

/** The academy findings for GOOD_META with one change. */
func metaProblems(old as string, new as string) {
    def found as list of Finding init checkedMeta(swap(GOOD_META, $old, $new));
    for (def f in $found) {
        testing.assertEqual($f.rule, "academy");
    }
    return messagesOf($found);
}

func testAcademyTomlSchema() {
    testing.assertEqual(checkedMeta(GOOD_META), []);
    testing.assertContains(
        metaProblems("level = \"beginner\"", "level = \"beginner\"\ncolour = \"red\""),
        "unknown key \"colour\"");
    testing.assertContains(
        metaProblems("level = \"beginner\"", "level = \"expert\""),
        "level must be");
    testing.assertContains(metaProblems("\"test-talk\"", "\"Test_Talk\""), "tag \"Test_Talk\"");
    testing.assertContains(
        metaProblems("\"basics\", ", "\"a\", \"b\", \"c\", \"d\", \"e\", \"f\", \"g\", \"h\", "),
        "tags must hold 1 to 8 tags, got 9");
    testing.assertContains(
        metaProblems("tags = [\"basics\", \"test-talk\"]", "tags = []"),
        "got 0");
    testing.assertContains(metaProblems("\"test-talk\"", "\"basics\""), "listed twice");
    testing.assertContains(
        metaProblems("author = \"ada\"", "author = \"bob\""),
        "namespace \"ada\"");
    testing.assertContains(
        metaProblems("CC-BY-4.0", "CC-BY-SA-4.0"),
        "license must be \"CC-BY-4.0\"");
    testing.assertContains(
        metaProblems("updated = \"2026-11\"", "updated = \"2026-09\""),
        "is before date");
    testing.assertContains(
        metaProblems("date = \"2026-10\"", "date = \"2026-10-01\""),
        "date must be YYYY-MM");
    testing.assertContains(metaProblems("lang = \"en\"", "lang = \"en-GB\""), "lang must be");
    testing.assertContains(
        metaProblems("jennifer = \"0.26.0\"", "jennifer = \"latest\""),
        "jennifer must be");
    testing.assertContains(
        metaProblems("date = \"2026-10\"", "date = 2026-10-01"),
        "date must be a string");
    testing.assertContains(
        metaProblems("tags = [\"basics\", \"test-talk\"]", "tags = \"basics\""),
        "tags must be a list");
    testing.assertContains(metaProblems("level = \"beginner\"\n", ""), "missing key \"level\"");
    testing.assertContains(
        metaProblems(", with a description long enough", ""),
        "description is 36 characters");
    testing.assertContains(
        metaProblems("A short talk", "See https://example.com, a short talk"),
        "no URLs");
    testing.assertContains(
        metaProblems("title = \"A good talk\"", "title = [\"x\"]"),
        "title must be a string");
    testing.assertContains(
        metaProblems("title = \"A good talk\"", "title = \"a\nb\""),
        "not valid TOML");
}

func testNameAndUpdatedAreOptional() {
    def entry as string init swap(
        swap(GOOD_META, "name = \"Ada Example\"\n", ""),
        "updated = \"2026-11\"\n",
        "");
    testing.assertEqual(checkedMeta($entry), []);
}

func testVersionMustBeStated() {
    def found as list of Finding init checkedMeta(swap(GOOD_META, "0.26.0", "0.27.0"));
    testing.assertEqual(rulesOf($found), ["version"]);
    testing.assertContains($found[0].message, "Based on Jennifer 0.27.0");
}

func testPrepareInjectsTheCatalogue() {
    def dir as string init makeTalk(
        "ada",
        "talk",
        swap(GOOD, "theme: plain", "theme: plain\nratio: 4:3"));
    def root as string init path.dir(path.dir(path.dir($dir)));
    defer fs.removeAll($root);
    fs.writeString(path.join($dir, "logo.png"), "x");
    def entry as meta.Checked init readMeta($dir, "ada");
    testing.assertEqual($entry.problems, []);
    def out as string init path.join($root, "prepared");
    def prepared as string init prepare($dir, $entry.meta, meta.versionsOf($entry.meta)[0], $out);
    def lines as list of string init strings.split(fs.readString($prepared), "\n");
    testing.assertEqual(
        $lines[0..12],
        [
            "---",
            "title: \"A good talk\"",
            "description: \"A short talk that passes every rule, with a description long enough.\"",
            "subject: \"A short talk that passes every rule, with a description long enough.\"",
            "keywords: \"jennifer, basics, test-talk\"",
            "lang: \"en\"",
            "author: \"Ada Example (@ada)\"",
            "date: \"2026-11\"",
            "notes: open",
            "theme: plain",
            "ratio: 4:3",
            "---",
        ]);
    def fm as FrontMatter init frontMatter($lines);
    testing.assertEqual($fm.values["title"], "A good talk");
    testing.assertEqual($fm.values["ratio"], "4:3");
    testing.assertTrue(fs.isFile(path.join($out, "logo.png")));
    testing.assertFalse(fs.isFile(path.join($out, "academy.toml")));
}

func testEmDashAndEnDashFail() {
    def em as string init convert.fromCodepoint(0x2014);
    def en as string init convert.fromCodepoint(0x2013);
    def found as list of Finding init checked(swap(
        GOOD,
        "## Second",
        "## Second " + $em + " and 1" + $en + "2"));
    testing.assertEqual(rulesOf($found), ["dashes", "dashes"]);
}

func testByteOrderMarkFails() {
    def dir as string init makeTalk("ada", "talk", "");
    defer fs.removeAll(path.dir(path.dir(path.dir($dir))));
    def data as bytes init encoding.encode("utf-8", GOOD);
    def withBom as bytes;
    $withBom[] = 0xef;
    $withBom[] = 0xbb;
    $withBom[] = 0xbf;
    for (def b in $data) {
        $withBom[] = $b;
    }
    fs.writeBytes(path.join($dir, "talk.md"), $withBom);
    testing.assertEqual(rulesOf(checkTalk($dir, "ada", fast())), ["encoding"]);
    def broken as bytes init $data;
    $broken[] = 0xff;
    fs.writeBytes(path.join($dir, "talk.md"), $broken);
    testing.assertEqual(rulesOf(checkTalk($dir, "ada", fast())), ["encoding"]);
}

func testNonParsingBlockFails() {
    def dir as string init makeTalk(
        "ada",
        "talk",
        swap(GOOD, "def x as int init 6 * 7;", "def x as int init ;"));
    defer fs.removeAll(path.dir(path.dir(path.dir($dir))));
    def opts as Options init fast();
    $opts.parseCode = true;
    def found as list of Finding init checkTalk($dir, "ada", $opts);
    testing.assertEqual(rulesOf($found), ["code"]);
    testing.assertEqual($found[0].line, 10);
    testing.assertContains($found[0].message, "does not parse");
}

func testExcerptIsOnlyLexed() {
    def fragment as string init "```jennifer excerpt\nfunc total(xs as list of int) \{ ... \}\n";
    def dir as string init makeTalk(
        "ada",
        "talk",
        swap(GOOD, "```jennifer\ndef x as int init 6 * 7;\n", $fragment));
    defer fs.removeAll(path.dir(path.dir(path.dir($dir))));
    def opts as Options init fast();
    $opts.parseCode = true;
    testing.assertEqual(checkTalk($dir, "ada", $opts), []);
    fs.writeString(
        path.join($dir, "talk.md"),
        padNotes(swap(GOOD, "def x as int init 6 * 7;", "def x as int init $y;")));
    testing.assertEqual(rulesOf(checkTalk($dir, "ada", $opts)), ["code"]);
}

func testCodeKind() {
    testing.assertEqual(codeKind("jennifer"), "code");
    testing.assertEqual(codeKind("jennifer excerpt"), "excerpt");
    testing.assertEqual(codeKind("  jennifer   excerpt "), "excerpt");
    testing.assertEqual(codeKind("text"), "");
    testing.assertEqual(codeKind(""), "");
    testing.assertEqual(codeKind("excerpt jennifer"), "");
}

func testUrlAllowlist() {
    def allowed as list of string init [
        "https://jennifer-lang.dev/",
        "https://docs.jennifer-lang.dev/modules/",
        "http://academy.jennifer-lang.dev/mplx/classroom/",
        "https://git.jennifer-lang.dev/jennifer-language/jennifer",
        "https://github.com/jennifer-language/jennifer",
        "https://github.com/jennifer-language",
        "https://github.com/Deckyard/deck-geo",
        "https://github.com/mplx/openconnect-saml",
        "https://github.com/topics/grimoire-plugin",
        "https://github.com/karpathy",
        "https://github.com/ada",
        "https://github.com/ada/demo/blob/main/x.j#L3",
        "www.jennifer-lang.dev",
    ];
    for (def u in $allowed) {
        testing.assertTrue(urlAllowed($u, "ada"));
    }
    def denied as list of string init [
        "https://example.com/",
        "https://jennifer-lang.dev.evil.test/",
        "https://evil-jennifer-lang.dev/",
        "https://jennifer-lang.dev@evil.test/",
        "https://jennifer-lang.dev:8443/",
        "https://github.com/",
        "https://github.com/bob/repo",
        "https://github.com/topics/other",
        "https://github.com/karpathy/micrograd",
        "https://gist.github.com/ada/1",
        "https://jennifer-language.github.io/cantrip/",
        "ftp://jennifer-lang.dev/",
        "mailto:mplx@jennifer-lang.dev",
        "javascript:alert(1)",
        "//jennifer-lang.dev/",
    ];
    for (def u in $denied) {
        testing.assertFalse(urlAllowed($u, "ada"));
    }
}

func testFindUrlsSkipsCode() {
    def lines as list of string init [
        "[a](https://a.test) and ![b](b.png \"title\") `https://code.test`",
        "<https://auto.test> and bare https://bare.test/x.",
        "```",
        "https://fenced.test",
        "```",
        "[ref]: <https://ref.test>",
        "``a `https://nested.test` b`` www.w.test",
    ];
    def found as list of UrlRef init findUrls(scan($lines));
    def urls as list of string;
    for (def r in $found) {
        $urls[] = $r.url;
    }
    testing.assertEqual(
        $urls,
        [
            "b.png",
            "https://a.test",
            "https://auto.test",
            "https://bare.test/x",
            "https://ref.test",
            "www.w.test"
        ]);
    testing.assertTrue($found[0].image);
    testing.assertEqual($found[4].line, 6);
}

func testStripCodeSpans() {
    testing.assertEqual(stripCodeSpans("a `b` c"), "a   c");
    testing.assertEqual(stripCodeSpans("a ``b ` c`` d"), "a   d");
    testing.assertEqual(stripCodeSpans("a `b c"), "a `b c");
}

func testSlidesFollowCantrip() {
    def lines as list of string init [
        "# One",
        "",
        "----",
        "",
        "---",
        "~~~~",
        "---",
        "~~~~",
        "<!-- notes: x ... -->",
        "---"
    ];
    def all as list of Slide init slides(scan($lines), 0);
    testing.assertEqual(len($all), 2);
    testing.assertFalse($all[0].hasNotes);
    testing.assertTrue($all[1].hasNotes);
    testing.assertEqual($all[1].line, 6);
}

func testFrontMatter() {
    def fm as FrontMatter init frontMatter([
        "---",
        "Title: \"A: B\"",
        "# c",
        "x",
        "ratio: 16:9",
        "---",
        "body"
    ]);
    testing.assertTrue($fm.found);
    testing.assertEqual($fm.values, {"title": "A: B", "ratio": "16:9"});
    testing.assertEqual($fm.lines["ratio"], 5);
    testing.assertEqual($fm.bodyStart, 6);
    testing.assertFalse(frontMatter(["---", "title: x"]).found);
    testing.assertFalse(frontMatter(["# x", "---"]).found);
}

func testNames() {
    testing.assertTrue(isValidUser("mplx"));
    testing.assertTrue(isValidUser("a-b-1"));
    testing.assertTrue(isValidUser(strings.replicate("a", 39)));
    testing.assertFalse(isValidUser(strings.replicate("a", 40)));
    testing.assertFalse(isValidUser("Mplx"));
    testing.assertFalse(isValidUser("-a"));
    testing.assertFalse(isValidUser("a--b"));
    testing.assertFalse(isValidUser("a_b"));
    testing.assertTrue(isValidSlug("intro-to-tasks"));
    testing.assertFalse(isValidSlug("Intro"));
    testing.assertFalse(isValidSlug("a.b"));
    testing.assertFalse(isValidSlug(""));
}

func testLayout() {
    def dir as string init makeTalk("ada", "good", GOOD);
    def talks as string init path.dir(path.dir($dir));
    defer fs.removeAll(path.dir($talks));
    testing.assertEqual(checkLayout($talks), []);
    fs.writeString(path.join($dir, "logo.png"), "x");
    testing.assertEqual(checkLayout($talks), []);
    fs.writeString(path.join($dir, "notes.txt"), "x");
    fs.mkdirAll(path.join($talks, "ada", "Bad_Slug"));
    fs.writeString(path.join($talks, "ada", "Bad_Slug", "talk.md"), GOOD);
    fs.writeString(path.join($talks, "ada", "Bad_Slug", "academy.toml"), GOOD_META);
    fs.mkdirAll(path.join($talks, "jennifer-language", "x"));
    fs.writeString(path.join($talks, "jennifer-language", "x", "talk.md"), GOOD);
    fs.writeString(path.join($talks, "jennifer-language", "x", "academy.toml"), GOOD_META);
    fs.mkdirAll(path.join($talks, "Ada2", "empty"));
    fs.writeString(path.join($talks, "README.md"), "x");
    def found as list of Finding init checkLayout($talks);
    def messages as string init "";
    for (def f in $found) {
        $messages = $messages + describe($f) + "\n";
    }
    testing.assertEqual(len($found), 7);
    testing.assertContains($messages, "README.md: layout:");
    testing.assertContains($messages, "Ada2: namespace:");
    testing.assertContains($messages, "empty: layout: " + MSG_NO_TALK);
    testing.assertContains($messages, "Bad_Slug: layout:");
    testing.assertContains($messages, "jennifer-language: namespace:");
    testing.assertContains($messages, "notes.txt: layout:");
}

func testDescribe() {
    testing.assertEqual(
        describe(Finding{file: "t.md", line: 3, rule: "links", message: "m"}),
        "t.md:3: links: m");
    testing.assertEqual(
        describe(Finding{file: "t.md", line: 0, rule: "build", message: "m"}),
        "t.md: build: m");
}

/** The overflow warning is caught; runs only where a cantrip checkout is found. */
func testBuildWarningFails() {
    def cantrip as string init "";
    if (os.hasEnv("CANTRIP") and os.getEnv("CANTRIP") != "") {
        $cantrip = os.getEnv("CANTRIP");
    }
    if ($cantrip == "") {
        return;
    }
    def long as string init strings.replicate("- a line\n", 60);
    def dir as string init makeTalk(
        "ada",
        "talk",
        swap(GOOD, "## Second\n", "## Second\n\n" + $long));
    defer fs.removeAll(path.dir(path.dir(path.dir($dir))));
    def opts as Options init fast();
    $opts.cantrip = $cantrip;
    $opts.build = true;
    def found as list of Finding init checkTalk($dir, "ada", $opts);
    testing.assertEqual(rulesOf($found), ["build"]);
    testing.assertContains($found[0].message, "cantrip: warning:");
    fs.writeString(path.join($dir, "talk.md"), padNotes(GOOD));
    testing.assertEqual(checkTalk($dir, "ada", $opts), []);
}

/** An imprint slide appended to a talk. */
def const IMPRINT as string init '
---

## Imprint

Ada Example, Vienna, Austria

<!-- notes: who is responsible for this talk ... -->
';

/** GOOD without the author on its title slide. */
func anonymous() {
    return swap(GOOD, "By @ada. Based", "Based");
}

func testAuthorByMention() {
    testing.assertEqual(checked(GOOD), []);
    testing.assertEqual(checked(swap(GOOD, "By @ada.", "(@ADA)")), []);
}

func testAuthorByProfileLink() {
    testing.assertEqual(checked(swap(GOOD, "By @ada.", "By [Ada](https://github.com/ada).")), []);
    testing.assertEqual(checked(swap(GOOD, "By @ada.", "By <https://github.com/ada/>.")), []);
}

func testAuthorByImprint() {
    testing.assertEqual(checked(anonymous() + IMPRINT), []);
}

func testAuthorByImpressumInGerman() {
    def de as string init swap(GOOD_META, "lang = \"en\"", "lang = \"de\"");
    def dir as string init makeTalkWith(
        "ada",
        "talk",
        anonymous() + swap(IMPRINT, "## Imprint", "## Impressum"),
        $de);
    defer fs.removeAll(path.dir(path.dir(path.dir($dir))));
    testing.assertEqual(checkTalk($dir, "ada", fast()), []);
    testing.assertEqual(
        rulesOf(checked(anonymous() + swap(IMPRINT, "## Imprint", "## Impressum"))),
        ["author"]);
}

func testNoAuthorFails() {
    def found as list of Finding init checked(anonymous());
    testing.assertEqual(rulesOf($found), ["author"]);
    testing.assertContains($found[0].message, "put @ada on the title slide");
    testing.assertEqual($found[0].line, 5);
}

func testOtherUsersMentionFails() {
    testing.assertEqual(
        rulesOf(checked(swap(GOOD, "By @ada.", "By @adam and ada@jennifer-lang.dev."))),
        ["author"]);
    def link as string init swap(GOOD, "By @ada.", "By [ada](https://github.com/bob).");
    testing.assertEqual(rulesOf(checked($link)), ["links", "author"]);
    def inNotes as string init swap(
        GOOD,
        "<!-- notes: hello ... -->",
        "<!-- notes: by @ada ... -->");
    testing.assertEqual(rulesOf(checked(swap($inNotes, "By @ada. ", ""))), ["author"]);
}

func testEmptyImprintFails() {
    def empty as string init swap(
        IMPRINT,
        "Ada Example, Vienna, Austria",
        "[@ada](https://github.com/ada)\n\n### Contact");
    testing.assertEqual(rulesOf(checked(anonymous() + $empty)), ["author"]);
}

func testImprintNotLastFails() {
    def text as string init swap(
        anonymous(),
        "---\n\n## Second",
        strings.trim(IMPRINT) + "\n\n---\n\n## Second");
    testing.assertEqual(rulesOf(checked($text)), ["author"]);
}

# ---------------------------------------------------------------------------
# Talks in several languages
# ---------------------------------------------------------------------------

/** The German version of GOOD. */
def const GOOD_DE as string init '---
theme: plain
---

# Ein guter Vortrag

Von @ada. Basierend auf Jennifer 0.26.0, mit Umlauten: ä ö ü ß é ² €.

<!-- notes: Begrüßung ... -->
';

/** The table GOOD_META gains for the German version. */
def const TABLE_DE as string init '
[translations.de]
title = "Ein guter Vortrag"
description = "Ein kurzer Vortrag, der alle Regeln erfüllt, mit langer Beschreibung dazu."
keywords = "jennifer, grundlagen"
';

/** A talk directory with the given files (name to text) and academy.toml. */
func makeFiles(files as map of string to string, entry as string) {
    def root as string init fs.makeTempDir("", "academy-test-");
    def dir as string init path.join($root, "talks", "ada", "talk");
    fs.mkdirAll($dir);
    for (def name in $files) {
        fs.writeString(path.join($dir, $name), padNotes($files[$name]));
    }
    fs.writeString(path.join($dir, "academy.toml"), $entry);
    return $dir;
}

/** Check a talk made of these files, layout included, and return the findings. */
func checkedFiles(files as map of string to string, entry as string) {
    def dir as string init makeFiles($files, $entry);
    defer fs.removeAll(path.dir(path.dir(path.dir($dir))));
    def out as list of Finding init checkLayout(path.dir(path.dir($dir)));
    for (def f in checkTalk($dir, "ada", fast())) {
        $out[] = $f;
    }
    return $out;
}

func testTwoLanguagesPass() {
    def files as map of string to string init {"talk.en.md": GOOD, "talk.de.md": GOOD_DE};
    testing.assertEqual(checkedFiles($files, GOOD_META + TABLE_DE), []);
}

func testTalkFileLang() {
    testing.assertEqual(talkFileLang("talk.md"), "");
    testing.assertEqual(talkFileLang("talk.de.md"), "de");
    testing.assertEqual(talkFileLang("talk.EN.md"), "EN");
    testing.assertEqual(talkFileLang("notes.md"), "-");
    testing.assertTrue(isTalkLang("de"));
    testing.assertFalse(isTalkLang("xx"));
    testing.assertFalse(isTalkLang("EN"));
    testing.assertFalse(isTalkLang("deu"));
    testing.assertEqual(len(meta.ISO_CODES), 183);
}

func testBothFormsFail() {
    def files as map of string to string init {"talk.md": GOOD, "talk.de.md": GOOD_DE};
    def found as list of Finding init checkedFiles($files, GOOD_META + TABLE_DE);
    def text as string init messagesOf($found);
    testing.assertContains($text, "layout: " + MSG_BOTH_FORMS);
    testing.assertContains($text, "[translations.de] has no talk.de.md");
}

func testBadLanguageCodesFail() {
    for (def bad in ["talk.xx.md", "talk.EN.md", "talk.deu.md"]) {
        def files as map of string to string init {"talk.en.md": GOOD};
        $files[$bad] = GOOD_DE;
        def found as list of Finding init checkedFiles($files, GOOD_META);
        testing.assertEqual(rulesOf($found), ["layout"]);
        testing.assertContains($found[0].message, "is not an ISO 639-1 code");
    }
}

func testMissingTableFails() {
    def files as map of string to string init {"talk.en.md": GOOD, "talk.de.md": GOOD_DE};
    def found as list of Finding init checkedFiles($files, GOOD_META);
    testing.assertEqual(rulesOf($found), ["languages"]);
    testing.assertContains($found[0].message, "talk.de.md has no [translations.de] table");
}

func testTableWithoutFileFails() {
    def files as map of string to string init {"talk.en.md": GOOD};
    def found as list of Finding init checkedFiles($files, GOOD_META + TABLE_DE);
    testing.assertEqual(rulesOf($found), ["languages"]);
    testing.assertContains($found[0].message, "[translations.de] has no talk.de.md");
}

func testPrimaryWithoutFileFails() {
    def files as map of string to string init {"talk.de.md": GOOD_DE};
    def entry as string init swap(GOOD_META, "lang = \"en\"", "lang = \"fr\"") + TABLE_DE;
    def found as list of Finding init checkedFiles($files, $entry);
    testing.assertEqual(rulesOf($found), ["languages"]);
    testing.assertContains($found[0].message, "lang is \"fr\" but there is no talk.fr.md");
}

func testTranslationTables() {
    testing.assertContains(metaProblems("lang = \"en\"", "lang = \"xx\""), "ISO 639-1");
    def t as string init GOOD_META + TABLE_DE;
    def problems as string init messagesOf(checkedFiles(
        {"talk.en.md": GOOD, "talk.de.md": GOOD_DE},
        swap($t, "keywords = ", "colour = ")));
    testing.assertContains($problems, "[translations.de]: unknown key \"colour\"");
    def short as string init swap(
        $t,
        "Ein kurzer Vortrag, der alle Regeln erfüllt, mit langer Beschreibung dazu.",
        "Zu kurz.");
    testing.assertContains(
        messagesOf(checkedFiles({"talk.en.md": GOOD, "talk.de.md": GOOD_DE}, $short)),
        "[translations.de] description is");
    def own as string init swap($t, "[translations.de]", "[translations.en]");
    testing.assertContains(
        messagesOf(checkedFiles({"talk.en.md": GOOD}, $own)),
        "en is the primary language");
}

func testEveryVersionIsChecked() {
    def bad as string init swap(
        GOOD_DE,
        "<!-- notes: Begrüßung ... -->",
        "[x](https://example.com)");
    def found as list of Finding init checkedFiles(
        {"talk.en.md": GOOD, "talk.de.md": $bad},
        GOOD_META + TABLE_DE);
    testing.assertEqual(rulesOf($found), ["links", "notes"]);
    testing.assertContains($found[0].file, "talk.de.md");
    def empty as list of Finding init checkedFiles(
        {
            "talk.en.md": GOOD,
            "talk.de.md": "---\ntheme: plain\n---\n"
        },
        GOOD_META + TABLE_DE);
    testing.assertEqual(rulesOf($empty), ["version", "notes"]);
    testing.assertContains($empty[1].message, "no slides");
}

func testImpressumByFileLanguage() {
    def de as string init swap(GOOD_DE, "Von @ada. ", "") +
        swap(IMPRINT, "## Imprint", "## Impressum");
    testing.assertEqual(
        checkedFiles({"talk.en.md": GOOD, "talk.de.md": $de}, GOOD_META + TABLE_DE),
        []);
    def en as string init anonymous() + swap(IMPRINT, "## Imprint", "## Impressum");
    testing.assertEqual(
        rulesOf(checkedFiles({"talk.en.md": $en, "talk.de.md": GOOD_DE}, GOOD_META + TABLE_DE)),
        ["author"]);
}

func testPrepareATranslation() {
    def dir as string init makeFiles(
        {"talk.en.md": GOOD, "talk.de.md": GOOD_DE},
        GOOD_META + TABLE_DE);
    def root as string init path.dir(path.dir(path.dir($dir)));
    defer fs.removeAll($root);
    def entry as meta.Checked init readMeta($dir, "ada");
    testing.assertEqual($entry.problems, []);
    def versions as list of meta.Version init meta.versionsOf($entry.meta);
    testing.assertEqual(len($versions), 2);
    def prepared as string init prepare($dir, $entry.meta, $versions[1], path.join($root, "de"));
    def fm as FrontMatter init frontMatter(strings.split(fs.readString($prepared), "\n"));
    testing.assertEqual($fm.values["title"], "Ein guter Vortrag");
    testing.assertEqual($fm.values["lang"], "de");
    testing.assertEqual($fm.values["keywords"], "jennifer, grundlagen");
    testing.assertContains(fs.readString($prepared), "# Ein guter Vortrag");
}

# ---------------------------------------------------------------------------
# The PDF's character set
# ---------------------------------------------------------------------------

func testArrowFailsTheCharset() {
    def arrow as string init convert.fromCodepoint(0x2192);
    def found as list of Finding init checked(swap(
        GOOD,
        "## Second",
        "## Second: a " + $arrow + " b"));
    testing.assertEqual(rulesOf($found), ["charset"]);
    testing.assertContains(
        $found[0].message,
        "U+2192 \"" + $arrow + "\" cannot be shown in the PDF");
    testing.assertEqual($found[0].line, 18);
}

func testEmojiFailsTheCharset() {
    def emoji as string init convert.fromCodepoint(0x1F600);
    def found as list of Finding init checked(swap(
        GOOD,
        "def x as int init 6 * 7;",
        "def x as int init 6 * 7; # " + $emoji));
    testing.assertEqual(rulesOf($found), ["charset"]);
    testing.assertContains($found[0].message, "U+1F600");
}

func testLatinTextPassesTheCharset() {
    testing.assertEqual(checkCharset("t.md", "ä ö ü ß é ² € Œ ™ ‘quotes’ “double” … • \t tab"), []);
    def greek as string init convert.fromCodepoint(0x03B1);
    testing.assertEqual(len(checkCharset("t.md", $greek + " and " + $greek)), 1);
}

func testTalkMayNotSetNotes() {
    def found as list of Finding init checked(swap(
        GOOD,
        "theme: plain",
        "theme: plain\nnotes: closed"));
    testing.assertEqual(rulesOf($found), ["front-matter"]);
    testing.assertContains($found[0].message, "\"notes\" is set by the academy");
}

/** Notes long enough for any slide, for building talks in the tests below. */
def const LONG_NOTE as string init "<!-- notes: long ... -->";

/** Words are counted between the opening of the notes and their close. */
func testNoteWords() {
    testing.assertEqual(noteWords("<!-- notes: one two -->"), 2);
    testing.assertEqual(noteWords("text before <!-- notes: three words here"), 3);
    testing.assertEqual(noteWords("  four words, then the -->  end"), 4);
    testing.assertEqual(noteWords("<!-- notes: -->"), 0);
    testing.assertEqual(noteWords("   "), 0);
}

/** A slide with fewer than MIN_NOTE_WORDS words of notes fails, naming the count. */
func testShortNotesFail() {
    def found as list of Finding init checked(swap(
        GOOD,
        "<!-- notes: the dashes",
        "<!-- notes: too short --> <!-- the dashes"));
    testing.assertEqual(rulesOf($found), ["notes"]);
    testing.assertContains($found[0].message, "slide 2 has 2 words");
    testing.assertContains($found[0].message, "at least 40");
}

/** A closing imprint needs notes, but they may be short; the same slide earlier may not. */
func testImprintNotesMayBeShort() {
    testing.assertEqual(checked(anonymous() + swap(IMPRINT, " ... -->", " -->")), []);
    def early as list of Finding init checked(GOOD + swap(IMPRINT, " ... -->", " -->") +
        "\n---\n\n## After\n\n" + LONG_NOTE +
        "\n");
    testing.assertEqual(rulesOf($early), ["notes"]);
    testing.assertContains($early[0].message, "slide 3 has");
}

/** A talk may have MAX_SLIDES slides, and one more fails at that slide. */
func testTooManySlidesFail() {
    def text as string init GOOD;
    for (def i in 0..MAX_SLIDES - 2) {
        $text = $text + "\n---\n\n## More\n\n" + LONG_NOTE + "\n";
    }
    testing.assertEqual(checked($text), []);
    def found as list of Finding init checked($text + "\n---\n\n## One too many\n\n" + LONG_NOTE +
        "\n");
    testing.assertEqual(rulesOf($found), ["length"]);
    testing.assertContains($found[0].message, "26 slides; at most 25");
}

/** A code folder's README that passes. */
def const CODE_README_TEXT as string init '# Programs

- `hello.j` (slides 3 to 5): `jennifer run hello.j`. Needs `jvc install` for the deck.
- See [the docs](https://docs.jennifer-lang.dev/) and `http://localhost:8080` in code.
';

/** A program that passes lint: it includes a helper and imports a deck that is not installed. */
def const CODE_PROGRAM as string init 'use io;
import "@jennifer/slack/" as slack;
include "helper.inc.j";

io.printf("%d %s\n", helper(), slack.name());
';

/** The include of CODE_PROGRAM. */
def const CODE_INCLUDE as string init 'func helper() {
    return 42;
}
';

/** A talk (GOOD) with a code folder holding these files (relative path to text). */
func makeCodeTalk(files as map of string to string) {
    def dir as string init makeTalk("ada", "talk", GOOD);
    for (def rel in $files) {
        def p as string init path.join($dir, "code", $rel);
        fs.mkdirAll(path.dir($p));
        fs.writeString($p, $files[$rel]);
    }
    return $dir;
}

/** The files of a code folder that passes every rule. */
func goodCode() {
    return {
        "README.md": CODE_README_TEXT,
        "LICENSE": mit0("2026 Ada Example"),
        "hello.j": CODE_PROGRAM,
        "helper.inc.j": CODE_INCLUDE,
        "deck.toml": "[decks]\n",
        "data/people.csv": "name,age\nAda,36\n",
        "web/page.tmpl": "<p>x</p>\n",
        "web/style.css": 'p { color: red; }' + "\n",
        "logo.png": "x"
    };
}

/** The layout and code findings of a talk with these code files (fast: no lint). */
func checkedCode(files as map of string to string) {
    def dir as string init makeCodeTalk($files);
    defer fs.removeAll(path.dir(path.dir(path.dir($dir))));
    def out as list of Finding init checkLayout(path.dir(path.dir($dir)));
    for (def f in checkTalk($dir, "ada", fast())) {
        $out[] = $f;
    }
    return $out;
}

/** goodCode with one file added or replaced. */
func codeWith(rel as string, text as string) {
    def files as map of string to string init goodCode();
    $files[$rel] = $text;
    return $files;
}

func testCodeFolderPasses() {
    testing.assertEqual(checkedCode(goodCode()), []);
}

func testCodeFolderNeedsReadme() {
    def files as map of string to string init goodCode();
    $files = maps.delete($files, "README.md");
    def found as list of Finding init checkedCode($files);
    testing.assertEqual(rulesOf($found), ["code-folder"]);
    testing.assertContains($found[0].message, "needs a README.md");
}

/** The MIT-0 licence text with this copyright holder line. */
func mit0(holder as string) {
    return MIT0_TITLE + "\n\nCopyright " + $holder + "\n\n" + MIT0_BODY;
}

/** A code folder needs its MIT-0 LICENSE. */
func testCodeFolderNeedsLicense() {
    def files as map of string to string init goodCode();
    $files = maps.delete($files, "LICENSE");
    def found as list of Finding init checkedCode($files);
    testing.assertEqual(rulesOf($found), ["code-license"]);
    testing.assertContains($found[0].message, "MIT-0");
}

/** Only the MIT-0 text passes; spacing and line breaks may differ. */
func testMit0Problem() {
    testing.assertEqual(mit0Problem(mit0("2026 Ada Example")), "");
    testing.assertEqual(mit0Problem(mit0("(c) 2025-2026, Ada Example")), "");
    def reflowed as string init strings.replace(
        mit0("2026 Ada"),
        "\nsoftware and",
        " software   and");
    testing.assertEqual(mit0Problem($reflowed), "");
    testing.assertContains(
        mit0Problem("MIT License\n\nCopyright 2026 Ada\n"),
        "MIT No Attribution");
    testing.assertContains(mit0Problem(mit0("Ada")), "Copyright <year> <holder>");
    def withAttribution as string init strings.replace(
        mit0("2026 Ada"),
        "furnished to do so.",
        "furnished to do so, subject to the following conditions:");
    testing.assertContains(mit0Problem($withAttribution), "word for word");
    testing.assertContains(mit0Problem(mit0("2026 Ada") + "Extra terms.\n"), "word for word");
}

/** A wrong licence text is reported at the LICENSE file. */
func testCodeFolderWrongLicense() {
    def files as map of string to string init goodCode();
    $files["LICENSE"] = "MIT License\n\nCopyright 2026 Ada\n";
    def found as list of Finding init checkedCode($files);
    testing.assertEqual(rulesOf($found), ["code-license"]);
}

func testOtherSubdirectoryFails() {
    def dir as string init makeTalk("ada", "talk", GOOD);
    def talks as string init path.dir(path.dir($dir));
    defer fs.removeAll(path.dir($talks));
    fs.mkdirAll(path.join($dir, "img"));
    def found as list of Finding init checkLayout($talks);
    testing.assertEqual(rulesOf($found), ["layout"]);
    testing.assertContains($found[0].message, "only subdirectory of a talk is code/");
}

func testCodeFolderFileTypes() {
    for (def rel in ["Makefile", "tool.exe", "notes.docx"]) {
        def found as list of Finding init checkedCode(codeWith($rel, "x"));
        testing.assertEqual(rulesOf($found), ["code-folder"]);
        testing.assertContains($found[0].message, "is not a file type code/ may hold");
    }
    for (def rel in ["out.pdf", "slides.html", "run.log"]) {
        def found as list of Finding init checkedCode(codeWith($rel, "x"));
        testing.assertEqual(rulesOf($found), ["code-folder"]);
        testing.assertContains($found[0].message, "no build output or logs");
    }
    for (def rel in ["server.pem", "server.key", "ca.crt", "id.p12"]) {
        def found as list of Finding init checkedCode(codeWith($rel, "x"));
        testing.assertEqual(rulesOf($found), ["code-folder"]);
        testing.assertContains($found[0].message, "no private keys or certificates");
    }
    for (def rel in [".gitignore", ".envrc", "app/.vscode/settings.json"]) {
        def hidden as list of Finding init checkedCode(codeWith($rel, "x\n"));
        testing.assertEqual(rulesOf($hidden), ["code-folder"]);
        testing.assertContains($hidden[0].message, "no hidden files");
    }
}

/** A forbidden directory is reported once, not once per file inside it. */
func testCodeFolderForbiddenDirectories() {
    def files as map of string to string init goodCode();
    $files["vendor/@jennifer/slack/src/slack.j"] = "x";
    $files["vendor/@jennifer/slack/deck.toml"] = "x";
    $files["build/a.txt"] = "x";
    $files["out/b.txt"] = "x";
    $files[".git/config"] = "x";
    def found as list of Finding init checkedCode($files);
    def four as list of string init ["code-folder", "code-folder", "code-folder", "code-folder"];
    testing.assertEqual(rulesOf($found), $four);
    def messages as string init messagesOf($found);
    testing.assertContains($messages, "code/.git: code-folder: no hidden files");
    testing.assertContains($messages, "code/build: code-folder: no build output");
    testing.assertContains($messages, "code/out: code-folder: no build output");
    testing.assertContains($messages, "code/vendor: code-folder: no vendor/");
}

func testCodeFolderDepth() {
    testing.assertEqual(checkedCode(codeWith("a/b/c/deep.txt", "x\n")), []);
    def found as list of Finding init checkedCode(codeWith("a/b/c/d/deeper.txt", "x\n"));
    testing.assertEqual(rulesOf($found), ["code-folder"]);
    testing.assertContains($found[0].message, "lies 5 levels below code/; at most 4");
}

/** An example app may bring its .github/ folder and dotenv files. */
func testCodeFolderDotenvAndGithub() {
    def files as map of string to string init goodCode();
    $files[".env"] = "TOKEN=placeholder\n";
    $files[".env.test"] = "TOKEN=test\n";
    $files["app/.env.local.example"] = "TOKEN=x\n";
    $files["app/.github/workflows/ci.yml"] = "on: push\n";
    testing.assertEqual(checkedCode($files), []);
    def key as string init "-----BEGIN " + "PRIVATE KEY-----\n";
    testing.assertEqual(rulesOf(checkedCode(codeWith(".env", $key))), ["code-folder"]);
    testing.assertTrue(isDotenv(".env.broken"));
    testing.assertFalse(isDotenv(".env."));
    testing.assertFalse(isDotenv(".envrc"));
}

/** A file without an extension is allowed in bin/ only, and only as a #! launcher. */
func testCodeFolderLaunchers() {
    def files as map of string to string init codeWith(
        "app/bin/tool",
        "#!/usr/bin/env -S jennifer run\nuse io;\n");
    testing.assertEqual(checkedCode($files), []);
    def plain as list of Finding init checkedCode(codeWith("app/bin/tool", "no shebang\n"));
    testing.assertEqual(rulesOf($plain), ["code-folder"]);
    testing.assertContains($plain[0].message, "its first line is #!");
    def outside as list of Finding init checkedCode(codeWith("app/tool", "#!/bin/sh\n"));
    testing.assertEqual(rulesOf($outside), ["code-folder"]);
    testing.assertContains($outside[0].message, "is not a file type");
    def binary as bytes init encoding.encode("utf-8", "#!x");
    $binary[] = 0;
    def dir as string init makeCodeTalk(goodCode());
    defer fs.removeAll(path.dir(path.dir(path.dir($dir))));
    fs.mkdirAll(path.join($dir, "code", "bin"));
    fs.writeBytes(path.join($dir, "code", "bin", "tool"), $binary);
    testing.assertContains(checkTalk($dir, "ada", fast())[0].message, "NUL bytes");
    testing.assertTrue(isLauncher("app/bin/tool"));
    testing.assertFalse(isLauncher("bin/tool.sh"));
    testing.assertFalse(isLauncher("tool"));
}

func testCodeFolderSymlinkFails() {
    def dir as string init makeCodeTalk(goodCode());
    defer fs.removeAll(path.dir(path.dir(path.dir($dir))));
    fs.symlink("../talk.md", path.join($dir, "code", "talk.md"));
    def found as list of Finding init checkTalk($dir, "ada", fast());
    testing.assertEqual(rulesOf($found), ["code-folder"]);
    testing.assertContains($found[0].message, "no symbolic links");
}

func testCodeFolderSizes() {
    def big as string init strings.replicate("x", MAX_CODE_FILE_BYTES);
    testing.assertEqual(checkedCode(codeWith("big.txt", $big)), []);
    def found as list of Finding init checkedCode(codeWith("big.txt", $big + "x"));
    testing.assertEqual(rulesOf($found), ["code-folder"]);
    testing.assertContains($found[0].message, "is 262145 bytes");
    def files as list of string init ["1", "2", "3", "4", "5", "6", "7", "8"];
    def many as map of string to string init goodCode();
    for (def n in $files) {
        $many["part" + $n + ".txt"] = $big;
    }
    def total as list of Finding init checkedCode($many);
    testing.assertEqual(rulesOf($total), ["code-folder"]);
    testing.assertContains($total[0].message, "at most 2097152 (2 MiB)");
}

func testCodeFolderForbiddenText() {
    def scratch as list of Finding init checkedCode(codeWith(
        "paths.txt",
        "ok\nsee /tmp/claude-1000/abc/scratchpad/x.j\n"));
    testing.assertEqual(rulesOf($scratch), ["code-folder"]);
    testing.assertEqual($scratch[0].line, 2);
    testing.assertContains($scratch[0].message, "absolute scratch path");
    def key as string init "-----BEGIN " + "OPENSSH PRIVATE KEY-----\nabc\n";
    def keys as list of Finding init checkedCode(codeWith("id.txt", $key));
    testing.assertContains($keys[0].message, "contains a private key");
    def pkcs8 as string init "-----BEGIN " + "PRIVATE KEY-----\n";
    testing.assertEqual(rulesOf(checkedCode(codeWith("k.txt", $pkcs8))), ["code-folder"]);
    def token as string init "token = \"ghp_" + strings.replicate("a1", 18) + "\"\n";
    testing.assertEqual(rulesOf(checkedCode(codeWith("cfg.toml", $token))), ["code-folder"]);
    # AWS's documented placeholder is fine, a real-looking key is not.
    testing.assertEqual(checkedCode(codeWith("aws.ini", "key = AKIAIOSFODNN7EXAMPLE\n")), []);
    testing.assertEqual(
        rulesOf(checkedCode(codeWith("aws.ini", "key = AKIAIOSFODNN7ABCDEFG\n"))),
        ["code-folder"]);
}

func testCodeFolderEncodingAndDashes() {
    def dir as string init makeCodeTalk(goodCode());
    defer fs.removeAll(path.dir(path.dir(path.dir($dir))));
    def broken as bytes init encoding.encode("utf-8", "abc");
    $broken[] = 0xff;
    fs.writeBytes(path.join($dir, "code", "data.txt"), $broken);
    testing.assertEqual(rulesOf(checkTalk($dir, "ada", fast())), ["encoding"]);
    def nul as bytes init encoding.encode("utf-8", "abc");
    $nul[] = 0;
    fs.writeBytes(path.join($dir, "code", "data.txt"), $nul);
    def found as list of Finding init checkTalk($dir, "ada", fast());
    testing.assertEqual(rulesOf($found), ["code-folder"]);
    testing.assertContains($found[0].message, "NUL bytes");
    # Any script is fine in code/ (no Windows-1252 rule there); dashes are not.
    def greek as string init "Greek alpha " + convert.fromCodepoint(0x3b1);
    fs.writeString(path.join($dir, "code", "data.txt"), $greek);
    testing.assertEqual(checkTalk($dir, "ada", fast()), []);
    def em as string init convert.fromCodepoint(0x2014);
    fs.writeString(path.join($dir, "code", "README.md"), CODE_README_TEXT + "a " + $em + " b\n");
    fs.writeString(path.join($dir, "code", "hello.j"), CODE_PROGRAM + "# a " + $em + " b\n");
    testing.assertEqual(rulesOf(checkTalk($dir, "ada", fast())), ["dashes", "dashes"]);
}

func testCodeReadmeLinks() {
    def found as list of Finding init checkedCode(codeWith(
        "README.md",
        CODE_README_TEXT + "\nSee [this](https://example.com/).\n"));
    testing.assertEqual(rulesOf($found), ["links"]);
    testing.assertContains($found[0].file, "code/README.md");
    # The reader's own machine is fine there, not in talk.md.
    def local as string init CODE_README_TEXT + "\nOpen http://127.0.0.1:8080/ or " +
        "<http://localhost:3000/x>.\n";
    testing.assertEqual(checkedCode(codeWith("README.md", $local)), []);
    testing.assertTrue(isLoopback("http://[::1]:8080"));
    testing.assertFalse(isLoopback("http://127.0.0.1.example.com/"));
    testing.assertFalse(isLoopback("http://localhost@example.com/"));
    testing.assertEqual(rulesOf(checked(GOOD + "\nSee http://127.0.0.1:8080/ too.\n")), ["links"]);
    # Links in other files are not links: a program may name any URL.
    testing.assertEqual(checkedCode(codeWith("urls.txt", "https://example.com/\n")), []);
}

func testCodeImports() {
    def ok as string init 'import "html.j";
import "./lib/util.j" as util;
';
    def files as map of string to string init codeWith("main.j", $ok);
    $files["lib/util.j"] = 'export func f() {
    return 1;
}
';
    testing.assertEqual(checkedCode($files), []);
    def missing as list of Finding init checkedCode(codeWith(
        "main.j",
        "use io;\nimport \"./nope.j\" as nope;\n"));
    testing.assertEqual(rulesOf($missing), ["code-folder"]);
    testing.assertEqual($missing[0].line, 2);
    testing.assertContains($missing[0].message, "import \"./nope.j\" is not a file in code/");
    def out as list of Finding init checkedCode(codeWith("main.j", 'include "../talk.md";\n'));
    testing.assertContains($out[0].message, "leads out of code/");
    def abs as list of Finding init checkedCode(codeWith("main.j", 'import "/etc/x.j" as x;\n'));
    testing.assertContains($abs[0].message, "an absolute path");
}

/** The release an L302 message names, and the order of two releases. */
func testRemovedInAndReleaseBefore() {
    testing.assertEqual(
        removedIn("`strings.repeat` was removed in 0.28.0; use `strings.replicate`"),
        "0.28.0");
    testing.assertEqual(removedIn("call to undefined function `f`"), "");
    testing.assertTrue(releaseBefore("0.26.0", "0.28.0"));
    testing.assertTrue(releaseBefore("0.9.0", "0.10.0"));
    testing.assertFalse(releaseBefore("0.28.0", "0.28.0"));
    testing.assertFalse(releaseBefore("1.0.0", "0.28.0"));
}

/** Only a clean catalogue entry with an X.Y.Z version pins a talk. */
func testPinnedRelease() {
    def m as meta.Meta;
    $m.jennifer = "0.26.0";
    testing.assertEqual(pinnedRelease(meta.Checked{meta: $m, problems: []}), "0.26.0");
    testing.assertEqual(pinnedRelease(meta.Checked{meta: $m, problems: ["bad"]}), "");
    $m.jennifer = "latest";
    testing.assertEqual(pinnedRelease(meta.Checked{meta: $m, problems: []}), "");
}

/** Lint runs on every program but an include; warnings fail, info does not. */
func testCodeLint() {
    def dir as string init makeCodeTalk(goodCode());
    defer fs.removeAll(path.dir(path.dir(path.dir($dir))));
    def opts as Options init fast();
    $opts.parseCode = true;
    # The deck import resolves nowhere (no vendor/), and lint accepts that.
    testing.assertEqual(checkTalk($dir, "ada", $opts), []);
    def long as string init "use io;\nio.printf(\"%s\\n\", \"" + strings.replicate("x", 120) +
        "\");\n";
    fs.writeString(path.join($dir, "code", "long.j"), $long);
    testing.assertEqual(checkTalk($dir, "ada", $opts), []);
    def unused as string init "use io;\nuse strings;\nio.printf(\"x\\n\");\n";
    fs.writeString(path.join($dir, "code", "unused.j"), $unused);
    def found as list of Finding init checkTalk($dir, "ada", $opts);
    testing.assertEqual(rulesOf($found), ["code-lint"]);
    testing.assertEqual($found[0].line, 2);
    testing.assertTrue(strings.endsWith($found[0].file, "code/unused.j"));
    testing.assertContains($found[0].message, "[L106]");
    fs.writeString(path.join($dir, "code", "unused.j"), "use io\nio.printf(\"x\\n\");\n");
    testing.assertContains(checkTalk($dir, "ada", $opts)[0].message, "[L002]");
    fs.remove(path.join($dir, "code", "unused.j"));
    # An include is checked through its program, not on its own.
    def bad as string init 'func g() {
    return $undefined;
}
';
    fs.writeString(path.join($dir, "code", "other.inc.j"), $bad);
    testing.assertEqual(checkTalk($dir, "ada", $opts), []);
    testing.assertEqual(deckPrograms($dir), [path.join($dir, "code", "hello.j")]);
}

func testCodeFiles() {
    def dir as string init makeCodeTalk(goodCode());
    defer fs.removeAll(path.dir(path.dir(path.dir($dir))));
    def rels as list of string;
    for (def e in codeFiles(path.join($dir, "code"))) {
        $rels[] = $e.rel;
    }
    testing.assertEqual(
        $rels,
        [
            "LICENSE",
            "README.md",
            "data/people.csv",
            "deck.toml",
            "hello.j",
            "helper.inc.j",
            "logo.png",
            "web/page.tmpl",
            "web/style.css"
        ]);
    testing.assertTrue(isProgram("a/hello.j"));
    testing.assertFalse(isProgram("helper.inc.j"));
    testing.assertFalse(isCodeText("logo.png"));
}

# --- plugins (rule 13) --------------------------------------------------

func pluginFindings(text as string) {
    def dir as string init fs.makeTempDir("", "academy-plugins-");
    defer fs.removeAll($dir);
    fs.writeString(path.join($dir, PLUGIN_CONFIG), $text);
    def out as list of string;
    for (def f in checkPlugins($dir)) {
        testing.assertEqual($f.rule == "plugins" or $f.rule == "dashes", true);
        $out[] = $f.message;
    }
    return $out;
}

func testAllowedPluginsPass() {
    testing.assertEqual(
        len(pluginFindings("[preprocessor.mermaid]\ntheme = \"dark\"\n\n[preprocessor.katex]\n")),
        0);
    testing.assertEqual(len(pluginFindings("")), 0);
    def none as string init fs.makeTempDir("", "academy-plugins-");
    testing.assertEqual(len(checkPlugins($none)), 0);
    fs.removeAll($none);
    testing.assertEqual(PLUGINS, ["mermaid", "katex"]);
    testing.assertEqual(PLUGIN_CANTRIP, "0.6.0");
}

func testATalkCannotChooseTheProgram() {
    def got as list of string init pluginFindings(
        "[preprocessor.mermaid]\ncommand = \"./evil.sh\"\nargs = [\"-x\"]\n");
    testing.assertEqual(len($got), 2);
    testing.assertContains($got[0], "preprocessor.mermaid.command");
    testing.assertContains($got[1], "preprocessor.mermaid.args");
    testing.assertEqual(PLUGIN_RESERVED, ["command", "args", "program"]);
    def renderer as list of string init pluginFindings(
        "[preprocessor.katex]\nprogram = \"/tmp/evil\"\n");
    testing.assertContains($renderer[0], "preprocessor.katex.program");
}

func testOnlyAllowlistedPluginsAndTablesPass() {
    testing.assertContains(pluginFindings("[preprocessor.include]\n")[0], "not one a talk may use");
    testing.assertContains(pluginFindings("[renderer.sitemap]\n")[0], "tables only");
    testing.assertContains(pluginFindings("theme = \"ivy\"\n")[0], "tables only");
    testing.assertContains(pluginFindings("[preprocessor\n")[0], "not valid TOML");
    testing.assertContains(pluginFindings("[preprocessor]\nmermaid = 1\n")[0], "must be a table");
}

func testThePathNoticeIsNotAFault() {
    testing.assertTrue(isPluginNotice(
        "cantrip: warning: preprocessor mermaid: runs /opt/p/bin/grimoire-mermaid, " +
            "found on PATH rather than in this deck"));
    testing.assertFalse(isPluginNotice(
        "cantrip: warning: preprocessor other: runs /x, found on PATH rather than in this deck"));
    testing.assertFalse(isPluginNotice("cantrip: warning: 2 slide(s) took 3 pages"));
}

# cantrip.toml is a file a talk may hold, and the prepared copy carries it.
func testTheConfigIsAllowedAndPrepared() {
    def dir as string init makeTalk("ada", "diagrams", GOOD);
    fs.writeString(path.join($dir, PLUGIN_CONFIG), "[preprocessor.mermaid]\n");
    def root as string init path.dir(path.dir(path.dir($dir)));
    defer fs.removeAll($root);
    for (def f in checkLayout(path.join($root, "talks"))) {
        testing.assertFalse(strings.contains($f.message, "talk directory holds"));
    }
    def entry as meta.Checked init readMeta($dir, "ada");
    def out as string init path.join($root, "prepared");
    prepare($dir, $entry.meta, meta.versionsOf($entry.meta)[0], $out);
    testing.assertTrue(fs.isFile(path.join($out, PLUGIN_CONFIG)));
}

func testAMissingPluginIsNamed() {
    testing.assertEqual(
        pluginMissing("preprocessor  mermaid  ->  cantrip-mermaid  (not found)"),
        "plugin \"mermaid\" is not installed: Cantrip found neither cantrip-mermaid nor " +
            "grimoire-mermaid on PATH (see CONTRIBUTING.md, \"Diagrams and maths\")");
}

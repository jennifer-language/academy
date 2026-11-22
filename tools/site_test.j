# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * Tests for the site's pages: the order of the talks and the escaping of
 * everything that comes from an academy.toml.
 * @module siteTest
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use encoding;
use testing;

/** A talk with the given title and months. */
func talk(topic as string, title as string, date as string, updated as string) {
    def m as meta.Meta init meta.Meta{
        title: $title,
        description: "A description of this talk, " + $topic + ", with \"quotes\" & <b>tags</b>.",
        author: "ada",
        name: "Ada <Example>",
        license: "CC-BY-4.0",
        lang: "en",
        jennifer: "0.26.0",
        date: $date,
        updated: $updated,
        level: "beginner",
        tags: ["basics", $topic],
        translations: [],
    };
    return Talk{user: "ada", topic: $topic, meta: $m, modified: "", code: []};
}

/** The talks of the tests, in no particular order. */
func sample() {
    return [
        talk("old", "Old talk", "2025-01", ""),
        talk("zeta", "Zeta", "2026-03", ""),
        talk("xss", "<script>alert(1)</script> & more", "2024-05", "2026-03"),
        talk("new", "New talk", "2026-11", ""),
    ];
}

/** The topics of a list of talks, in order. */
func topicsOf(talks as list of Talk) {
    def out as list of string;
    for (def t in $talks) {
        $out[] = $t.topic;
    }
    return $out;
}

func testNewestFirstThenTitle() {
    # xss was updated 2026-03, so it sorts with zeta, and "<script..." < "zeta".
    testing.assertEqual(topicsOf(sorted(sample())), ["new", "xss", "zeta", "old"]);
}

func testFrontPageEscapes() {
    def page as string init indexPage(sorted(sample()));
    testing.assertFalse(strings.contains($page, "<script>alert"));
    testing.assertContains($page, "&lt;script&gt;alert(1)&lt;/script&gt; &amp; more");
    testing.assertContains($page, "with &quot;quotes&quot; &amp; &lt;b&gt;tags&lt;/b&gt;.");
    testing.assertContains(
        $page,
        "Ada &lt;Example&gt; (<a href=\"https://github.com/ada\">@ada</a>)");
    testing.assertFalse(strings.contains($page, "<b>tags</b>"));
    # The JSON-LD cannot close its script element either.
    testing.assertContains($page, "\\u003cscript\\u003ealert(1)\\u003c/script\\u003e \\u0026 more");
    # Two JSON-LD blocks (the site with its search, the talks) and the search script.
    testing.assertEqual(strings.count($page, "</script>"), 3);
}

func testFrontPageOrderAndLinks() {
    def page as string init indexPage(sorted(sample()));
    def at as list of int;
    # One level only: the cards go by title ("<script..." sorts first).
    for (def topic in ["xss", "new", "old", "zeta"]) {
        $at[] = strings.indexOf($page, "href=\"talks/ada/" + $topic + "/\"");
    }
    testing.assertTrue($at[0] > 0 and $at[0] < $at[1] and $at[1] < $at[2] and $at[2] < $at[3]);
    testing.assertContains($page, "href=\"talks/ada/new/new.pdf\"");
    testing.assertContains($page, "href=\"tags/basics/\"");
    testing.assertContains($page, "data-level=\"beginner\" data-tags=\"basics new\"");
    # The filter bar: dropdowns with a count per option, hidden until the script runs.
    testing.assertContains($page, "<form class=\"filters\" id=\"filters\" hidden>");
    testing.assertContains(
        $page,
        "<select data-kind=\"level\"><option value=\"\">All levels</option>" +
            "<option value=\"beginner\">Beginner (4)</option></select>");
    testing.assertContains($page, "<option value=\"basics\">basics (4)</option>");
    # A topic of one talk is left out of the dropdown; its card still links it.
    testing.assertFalse(strings.contains($page, "<option value=\"zeta\">"));
    testing.assertContains($page, "<a href=\"tags/zeta/\">zeta</a>");
    testing.assertContains($page, "id=\"filter-q\"");
    # Each card carries its level as a class (the colour) and as text.
    testing.assertContains(
        $page,
        "<li class=\"talk beginner\" lang=\"en\" data-level=\"beginner\"");
    testing.assertContains($page, "<a class=\"level\" href=\"levels/beginner/\">Beginner</a>");
    testing.assertTrue(strings.contains($page, "<script>"));
    # One language: Slides and PDF buttons only, no language badges.
    testing.assertFalse(strings.contains($page, "class=\"langs\""));
    testing.assertFalse(strings.contains($page, "class=\"badge\""));
    testing.assertContains(
        $page,
        "<link rel=\"canonical\" href=\"https://academy.jennifer-lang.dev/\">");
}

func testOtherPages() {
    def all as list of Talk init sorted(sample());
    testing.assertContains(userPage($all, "ada"), "href=\"../../talks/ada/new/\"");
    def tagged as string init tagPage($all, "zeta");
    testing.assertContains($tagged, "href=\"../../talks/ada/zeta/\"");
    testing.assertFalse(strings.contains($tagged, "talks/ada/new/"));
    testing.assertEqual(tagsOf($all), ["basics", "new", "old", "xss", "zeta"]);
    def map2 as string init sitemap($all);
    testing.assertContains(
        $map2,
        "<loc>https://academy.jennifer-lang.dev/talks/ada/xss/</loc><lastmod>2026-03</lastmod>");
    testing.assertContains($map2, "<loc>https://academy.jennifer-lang.dev/tags/zeta/</loc>");
    testing.assertContains(robots(), "Sitemap: https://academy.jennifer-lang.dev/sitemap.xml");
    def legal as string init legalPage("# Legal\n\n<b>x</b>\n");
    testing.assertContains($legal, "&lt;b&gt;x&lt;/b&gt;");
    testing.assertContains($legal, "<title>Legal - Jennifer Academy</title>");
    testing.assertContains($legal, "<h2>Disclaimer</h2>");
    testing.assertContains($map2, "<loc>https://academy.jennifer-lang.dev/legal/</loc>");
    testing.assertContains(indexPage($all), "<a href=\"legal/\">Legal</a>");
    testing.assertContains(userPage($all, "ada"), "<a href=\"../../legal/\">Legal</a>");
}

/** Talks live under talks/, apart from the site's own pages, with a handout each. */
func testTalksDirAndHandouts() {
    def all as list of Talk init sorted(sample());
    def page as string init indexPage($all);
    testing.assertContains($page, "href=\"talks/ada/new/new-handout.pdf\"");
    testing.assertContains(
        userPage($all, "ada"),
        "<link rel=\"canonical\" href=\"" +
            SITE_URL + "talks/ada/\">");
    def doc as json.Value init json.decode(catalogue($all));
    def topic as string init json.asString($doc, "/talks/0/topic");
    testing.assertEqual(
        json.asString($doc, "/talks/0/handout"),
        SITE_URL + "talks/ada/" + $topic + "/" + $topic + "-handout.pdf");
    testing.assertContains(sitemap($all), "<loc>" + SITE_URL + "talks/ada/</loc>");
}

/** Talks published before the move redirect from their old address; later ones do not. */
func testLegacyRedirects() {
    def all as list of Talk init sorted(sample());
    for (def t in $all) {
        testing.assertEqual(isLegacy($t), $t.meta.date <= LEGACY_UNTIL);
    }
    def page as string init redirectPage(SITE_URL + "talks/ada/old/");
    testing.assertContains(
        $page,
        "<link rel=\"canonical\" href=\"https://academy.jennifer-lang.dev/talks/ada/old/\">");
    testing.assertContains(
        $page,
        "content=\"0; url=https://academy.jennifer-lang.dev/talks/ada/old/\"");
    testing.assertContains($page, "<meta name=\"robots\" content=\"noindex\">");
    testing.assertContains(redirectPage("a\"b"), "a&quot;b");
    def t as Talk init $all[0];
    $t.user = "legal";
    testing.assertFalse(isLegacy($t));
}

func testCatalogue() {
    def doc as json.Value init json.decode(catalogue(sorted(sample())));
    testing.assertEqual(json.length($doc, "/talks"), 4);
    testing.assertEqual(json.asString($doc, "/talks/1/title"), "<script>alert(1)</script> & more");
    testing.assertEqual(
        json.asString($doc, "/talks/0/pdf"),
        "https://academy.jennifer-lang.dev/talks/ada/new/new.pdf");
    testing.assertEqual(json.asString($doc, "/talks/0/tags/1"), "new");
}

/** A talk in English with a German translation. */
func bilingual() {
    def t as Talk init talk("duo", "Two languages", "2026-12", "");
    $t.meta.translations = [
        meta.Translation{
            lang: "de",
            title: "Zwei Sprachen <de>",
            description: "Ein Vortrag in zwei Sprachen, mit einer langen Beschreibung dazu.",
            keywords: "",
        }
    ];
    return $t;
}

func testHeadLinksOnSlides() {
    def t as Talk init talk("new", "New", "2026-11", "");
    def v as meta.Version init meta.versionsOf($t.meta)[0];
    def page as string init withHead("<html><head><title>x</title>", $t, $v);
    testing.assertContains(
        $page,
        "<head>\n<link rel=\"canonical\" href=\"" + SITE_URL + "talks/ada/new/\">");
    testing.assertContains(
        $page,
        "<link rel=\"alternate\" hreflang=\"x-default\" href=\"" + SITE_URL +
            "talks/ada/new/\"><title>x</title>");
}

func testTranslationsGetBadgesAndHreflang() {
    def b as Talk init bilingual();
    def de as meta.Version init meta.versionsOf($b.meta)[1];
    def page as string init withHead("<head></head>", $b, $de);
    testing.assertContains(
        $page,
        "<link rel=\"canonical\" href=\"" + SITE_URL + "talks/ada/duo/de/\">");
    testing.assertContains($page, "hreflang=\"en\" href=\"" + SITE_URL + "talks/ada/duo/\">");
    testing.assertContains($page, "hreflang=\"de\" href=\"" + SITE_URL + "talks/ada/duo/de/\">");
    testing.assertContains(
        $page,
        "hreflang=\"x-default\" href=\"" + SITE_URL + "talks/ada/duo/\">");
    def all as list of Talk init sample();
    $all[] = $b;
    $all = sorted($all);
    def index as string init indexPage($all);
    testing.assertContains($index, "data-langs=\"en de\"");
    # Badges only on the talk with a translation.
    testing.assertEqual(strings.count($index, "<ul class=\"langs\">"), 1);
    testing.assertContains(
        $index,
        "<a class=\"badge\" href=\"talks/ada/duo/\" hreflang=\"en\" " +
            "title=\"Two languages\">EN</a>");
    testing.assertContains(
        $index,
        "href=\"talks/ada/duo/de/\" hreflang=\"de\" title=\"Zwei Sprachen &lt;de&gt;\">DE</a>");
    testing.assertContains($index, "href=\"talks/ada/duo/de/index.pdf\" hreflang=\"de\"");
    testing.assertContains($index, "href=\"talks/ada/duo/duo.pdf\" hreflang=\"en\"");
    testing.assertContains(
        $index,
        "<select data-kind=\"lang\"><option value=\"\">All languages</option>" +
            "<option value=\"de\">DE (1)</option><option value=\"en\">EN (");
    testing.assertEqual(langsIn($all), ["de", "en"]);
    # One language in the whole catalogue: no language dropdown.
    testing.assertFalse(strings.contains(indexPage(sorted(sample())), "data-kind=\"lang\""));
    def map2 as string init sitemap($all);
    testing.assertContains($map2, "xmlns:xhtml=\"http://www.w3.org/1999/xhtml\"");
    testing.assertContains($map2, "<loc>" + SITE_URL + "talks/ada/duo/de/</loc>");
    testing.assertContains(
        $map2,
        "<xhtml:link rel=\"alternate\" hreflang=\"de\" href=\"" + SITE_URL +
            "talks/ada/duo/de/\"/>");
    testing.assertContains($map2, "<loc>" + SITE_URL + "talks/ada/duo/de/index.pdf</loc>");
    def doc as json.Value init json.decode(catalogue($all));
    testing.assertEqual(json.asString($doc, "/talks/0/topic"), "duo");
    testing.assertEqual(json.length($doc, "/talks/0/versions"), 2);
    testing.assertEqual(
        json.asString($doc, "/talks/0/versions/1/url"),
        SITE_URL + "talks/ada/duo/de/");
    testing.assertEqual(json.asString($doc, "/talks/0/versions/1/title"), "Zwei Sprachen <de>");
    testing.assertFalse(json.asBool($doc, "/talks/0/versions/1/primary"));
}

/** The sample with one talk per level, the advanced one first by title. */
func mixed() {
    def out as list of Talk init sample();
    $out[0].meta.level = "advanced";
    $out[1].meta.level = "intermediate";
    return $out;
}

func testCardsGoByLevelThenTitle() {
    testing.assertEqual(topicsOf(shown(mixed())), ["xss", "new", "zeta", "old"]);
    def page as string init indexPage(sorted(mixed()));
    testing.assertTrue(
        strings.indexOf($page, "href=\"talks/ada/new/\"") <
            strings.indexOf($page, "href=\"talks/ada/zeta/\""));
    testing.assertTrue(
        strings.indexOf($page, "href=\"talks/ada/zeta/\"") <
            strings.indexOf($page, "href=\"talks/ada/old/\""));
    testing.assertContains($page, "<option value=\"newest\">Newest first</option>");
    testing.assertContains($page, "data-month=\"2026-11\"");
}

func testSearchAndLevelRoutes() {
    def all as list of Talk init sorted(mixed());
    def index as string init indexPage($all);
    # The header search: on the front page it filters, elsewhere it goes there with ?q=.
    testing.assertContains($index, "<form class=\"search\" action=\"\" method=\"get\"");
    testing.assertContains(tagPage($all, "zeta"), "<form class=\"search\" action=\"../../\"");
    testing.assertContains($index, '"urlTemplate":"' + SITE_URL + '?q={search_term_string}"');
    testing.assertContains($index, "<a class=\"level\" href=\"levels/advanced/\">Advanced</a>");
    testing.assertEqual(levelsOf($all), ["beginner", "intermediate", "advanced"]);
    # Beside the intro: one box per level, with its count and its page.
    testing.assertContains(
        $index,
        "<nav class=\"bylevel\" aria-label=\"Talks by level\"><a class=\"beginner\" " +
            "href=\"levels/beginner/\"><strong>Beginner</strong><span class=\"n\">2 talks</span>");
    testing.assertContains(
        $index,
        "href=\"levels/advanced/\"><strong>Advanced</strong><span class=\"n\">1 talk</span>");
    def advanced as string init levelPage($all, "advanced");
    testing.assertContains($advanced, "<h1>Advanced talks</h1>");
    # A count and the way to the other levels; the current one is not a link.
    testing.assertContains(
        $advanced,
        "<nav class=\"pagenav\" aria-label=\"Levels\"><p class=\"count\">1 talk</p>" +
            "<a href=\"../../\">All talks</a><a href=\"../beginner/\">Beginner</a>" +
            "<a href=\"../intermediate/\">Intermediate</a>" +
            "<span aria-current=\"page\">Advanced</span></nav>");
    # Every card there has the same level, so it carries no label.
    testing.assertFalse(strings.contains($advanced, "class=\"level\""));
    testing.assertContains(tagPage($all, "zeta"), "<a class=\"level\" href=\"../../levels/");
    # A tag page: the count, the way back, and its own tag marked, not linked.
    def zeta as string init tagPage($all, "zeta");
    testing.assertContains(
        $zeta,
        "<nav class=\"pagenav\" aria-label=\"Talks\"><p class=\"count\">1 talk</p>" +
            "<a href=\"../../\">All talks</a></nav>");
    testing.assertContains($zeta, "<span class=\"current\" aria-current=\"page\">zeta</span>");
    testing.assertFalse(strings.contains($zeta, "href=\"../../tags/zeta/\""));
    testing.assertContains($zeta, "href=\"../../tags/basics/\"");
    testing.assertContains($advanced, "href=\"../../talks/ada/old/\"");
    testing.assertFalse(strings.contains($advanced, "href=\"../../talks/ada/new/\""));
    testing.assertContains(
        $advanced,
        "<link rel=\"canonical\" href=\"" + SITE_URL + "levels/advanced/\">");
    testing.assertContains(sitemap($all), "<loc>" + SITE_URL + "levels/intermediate/</loc>");
    def llms as string init llmsTxt($all);
    testing.assertTrue(strings.startsWith($llms, "# Jennifer Academy\n\n> "));
    testing.assertContains(
        $llms,
        "## Intermediate talks\n\n- [Zeta](" + SITE_URL + "talks/ada/zeta/): ");
    testing.assertContains(
        $llms,
        "Tags: basics, zeta. PDF: " + SITE_URL + "talks/ada/zeta/zeta.pdf");
}

func testGitDayIsWhatMachinesSee() {
    def all as list of Talk init sorted(sample());
    $all[0].modified = "2026-11-17";
    testing.assertEqual(modifiedOf($all[0]), "2026-11-17");
    testing.assertEqual(modifiedOf($all[1]), meta.latest($all[1].meta));
    def urls as string init sitemap($all);
    testing.assertContains(
        $urls,
        "<loc>" + SITE_URL + "talks/ada/new/</loc><lastmod>2026-11-17</lastmod>");
    testing.assertContains(
        $urls,
        "<loc>" + SITE_URL + "talks/ada/new/new.pdf</loc><lastmod>2026-11-17");
    testing.assertContains(indexPage($all), "\"dateModified\":\"2026-11-17\"");
    def doc as json.Value init json.decode(catalogue($all));
    testing.assertEqual(json.asString($doc, "/talks/0/modified"), "2026-11-17");
    testing.assertEqual(json.asString($doc, "/talks/0/updated"), "");
    # Readers keep seeing the author's month.
    testing.assertContains(indexPage($all), "<time datetime=\"2026-11\">2026-11</time>");
}

/** A talk with a code folder: a README, a program in a subfolder, and an image. */
func withCode() {
    def t as Talk init talk("code", "Code <talk>", "2026-12", "");
    $t.code = [
        CodeFile{path: "README.md", size: 120, text: true},
        CodeFile{path: "logo.png", size: 2048, text: false},
        CodeFile{path: "srv/main.j", size: 3500, text: true},
        CodeFile{path: "srv/.github/workflows/ci.yml", size: 10, text: true}
    ];
    return $t;
}

func testCodeLinksOnlyWhereThereIsCode() {
    def all as list of Talk init sample();
    $all[] = withCode();
    $all = sorted($all);
    def index as string init indexPage($all);
    testing.assertEqual(strings.count($index, ">Code</a>"), 1);
    testing.assertContains(
        $index,
        "<a href=\"talks/ada/code/code/\" title=\"The programs behind the slides\">Code</a>");
    testing.assertContains(userPage($all, "ada"), "href=\"../../talks/ada/code/code/\"");
    def doc as json.Value init json.decode(catalogue($all));
    testing.assertEqual(json.asString($doc, "/talks/0/topic"), "code");
    testing.assertEqual(json.asString($doc, "/talks/0/code"), SITE_URL + "talks/ada/code/code/");
    testing.assertEqual(
        json.asString($doc, "/talks/0/codeZip"),
        SITE_URL + "talks/ada/code/code-code.zip");
    # A talk without code/ has neither field.
    testing.assertFalse(json.has($doc, "/talks/1/code"));
    testing.assertFalse(json.has($doc, "/talks/1/codeZip"));
    def llms as string init llmsTxt($all);
    testing.assertContains(
        $llms,
        ". Code: " + SITE_URL + "talks/ada/code/code/ (zip: " + SITE_URL +
            "talks/ada/code/code-code.zip)\n");
    testing.assertEqual(strings.count($llms, ". Code: "), 1);
    testing.assertContains(sitemap($all), "<loc>" + SITE_URL + "talks/ada/code/code/</loc>");
}

func testCodePage() {
    def t as Talk init withCode();
    def page as string init codePage($t, "# Programs\n\n- `main.j`: <b>run</b> it\n");
    testing.assertContains($page, "<h1>Code: Code &lt;talk&gt;</h1>");
    testing.assertContains($page, "<h1>Programs</h1>");
    testing.assertContains($page, "&lt;b&gt;run&lt;/b&gt;");
    testing.assertFalse(strings.contains($page, "<b>run</b>"));
    # Text files link their page and their raw copy; an image links itself.
    testing.assertContains(
        $page,
        "<tr><td><a href=\"srv/main.j.html\">srv/main.j</a></td><td class=\"size\">3.4 KiB</td>" +
            "<td><a href=\"srv/main.j\">raw</a></td></tr>");
    testing.assertContains(
        $page,
        "<tr><td><a href=\"logo.png\">logo.png</a></td><td class=\"size\">2.0 KiB</td><td></td>");
    testing.assertContains(
        $page,
        "<a href=\"../../../../talks/ada/code/code-code.zip\" download>All files as zip</a>");
    testing.assertContains($page, "<a href=\"../../../../talks/ada/code/\">Slides</a>");
    # A hidden path is in the zip only: Pages leaves .github out.
    testing.assertContains(
        $page,
        "<tr><td>srv/.github/workflows/ci.yml</td><td class=\"size\">10 B</td>" +
            "<td>in the zip</td></tr>");
    testing.assertTrue(zipOnly(CodeFile{path: ".env", size: 1, text: true}));
    testing.assertFalse(zipOnly($t.code[2]));
    testing.assertContains($page, "href=\"../../../../jennifer.svg\"");
    testing.assertContains(
        $page,
        "<link rel=\"canonical\" href=\"" + SITE_URL + "talks/ada/code/code/\">");
    testing.assertEqual(sizeText(812), "812 B");
    testing.assertEqual(sizeText(1024), "1.0 KiB");
}

func testCodeFilePage() {
    def t as Talk init withCode();
    def f as CodeFile init $t.code[2];
    testing.assertEqual(viewPath($f), "srv/main.j.html");
    # The highlighted fragment goes in as cantrip wrote it, escaped already.
    def code as string init '<span class="hljs-keyword">if</span> ($a &lt; $b) {}';
    def page as string init codeFilePage($t, $f, $code);
    testing.assertContains($page, "<pre class=\"source\"><code>" + $code + "</code></pre>");
    # One level deeper than the listing: the way back and to the raw file.
    testing.assertContains($page, "<a href=\"../\">All files</a><a href=\"main.j\">raw</a>");
    testing.assertContains($page, "href=\"../../../../../jennifer.svg\"");
    def top as string init codeFilePage($t, $t.code[0], "# Programs");
    testing.assertContains($top, "<a href=\"./\">All files</a><a href=\"README.md\">raw</a>");
    testing.assertContains(
        $page,
        "<link rel=\"canonical\" href=\"" + SITE_URL + "talks/ada/code/code/srv/main.j.html\">");
}

/** The zip is the same bytes for the same files, in any order, below <topic>/. */
func testCodeZipIsDeterministic() {
    def t as Talk init withCode();
    def a as archive.Entry init archive.Entry{
        name: "srv/main.j",
        data: encoding.encode("utf-8", "use io;\n"),
        mode: 0o755,
        mtime: 1700000000
    };
    def b as archive.Entry init archive.Entry{
        name: "README.md",
        data: encoding.encode("utf-8", "# Programs\n"),
        mode: 0o600,
        mtime: 1
    };
    def zip as bytes init codeZip($t, [$a, $b]);
    testing.assertEqual(codeZip($t, [$b, $a]), $zip);
    def back as list of archive.Entry init archive.unpack("zip", $zip);
    testing.assertEqual(len($back), 2);
    testing.assertEqual($back[0].name, "code/README.md");
    testing.assertEqual($back[1].name, "code/srv/main.j");
    testing.assertEqual($back[1].mode, 0o644);
    testing.assertEqual($back[1].mtime, ZIP_MTIME);
    testing.assertEqual(encoding.decode("utf-8", $back[1].data), "use io;\n");
}

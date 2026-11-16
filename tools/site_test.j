# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * Tests for the site's pages: the order of the talks and the escaping of
 * everything that comes from an academy.toml.
 * @module siteTest
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

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
    return Talk{user: "ada", topic: $topic, meta: $m};
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
    testing.assertEqual(strings.count($page, "</script>"), 2);
}

func testFrontPageOrderAndLinks() {
    def page as string init indexPage(sorted(sample()));
    def at as list of int;
    for (def topic in ["new", "xss", "zeta", "old"]) {
        $at[] = strings.indexOf($page, "href=\"ada/" + $topic + "/\"");
    }
    testing.assertTrue($at[0] > 0 and $at[0] < $at[1] and $at[1] < $at[2] and $at[2] < $at[3]);
    testing.assertContains($page, "href=\"ada/new/new.pdf\"");
    testing.assertContains($page, "href=\"tags/basics/\"");
    testing.assertContains($page, "data-level=\"beginner\" data-tags=\"basics new\"");
    testing.assertContains($page, "<div class=\"filters\" id=\"filters\" hidden>");
    testing.assertContains($page, "data-kind=\"level\" data-value=\"beginner\"");
    testing.assertContains(
        $page,
        "<link rel=\"canonical\" href=\"https://academy.jennifer-lang.dev/\">");
}

func testOtherPages() {
    def all as list of Talk init sorted(sample());
    testing.assertContains(userPage($all, "ada"), "href=\"../ada/new/\"");
    def tagged as string init tagPage($all, "zeta");
    testing.assertContains($tagged, "href=\"../../ada/zeta/\"");
    testing.assertFalse(strings.contains($tagged, "ada/new/"));
    testing.assertEqual(tagsOf($all), ["basics", "new", "old", "xss", "zeta"]);
    def map2 as string init sitemap($all);
    testing.assertContains(
        $map2,
        "<loc>https://academy.jennifer-lang.dev/ada/xss/</loc><lastmod>2026-03</lastmod>");
    testing.assertContains($map2, "<loc>https://academy.jennifer-lang.dev/tags/zeta/</loc>");
    testing.assertContains(robots(), "Sitemap: https://academy.jennifer-lang.dev/sitemap.xml");
    def legal as string init legalPage("# Legal\n\n<b>x</b>\n");
    testing.assertContains($legal, "&lt;b&gt;x&lt;/b&gt;");
    testing.assertContains($legal, "<title>Legal - Jennifer Academy</title>");
    testing.assertContains($legal, "<h2>Disclaimer</h2>");
    testing.assertContains($map2, "<loc>https://academy.jennifer-lang.dev/legal/</loc>");
    testing.assertContains(indexPage($all), "<a href=\"legal/\">Legal</a>");
    testing.assertContains(userPage($all, "ada"), "<a href=\"../legal/\">Legal</a>");
}

func testCatalogue() {
    def doc as json.Value init json.decode(catalogue(sorted(sample())));
    testing.assertEqual(json.length($doc, "/talks"), 4);
    testing.assertEqual(json.asString($doc, "/talks/1/title"), "<script>alert(1)</script> & more");
    testing.assertEqual(
        json.asString($doc, "/talks/0/pdf"),
        "https://academy.jennifer-lang.dev/ada/new/new.pdf");
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
        "<head>\n<link rel=\"canonical\" href=\"" + SITE_URL + "ada/new/\">");
    testing.assertContains(
        $page,
        "<link rel=\"alternate\" hreflang=\"x-default\" href=\"" + SITE_URL +
            "ada/new/\"><title>x</title>");
}

func testTranslationsGetBadgesAndHreflang() {
    def b as Talk init bilingual();
    def de as meta.Version init meta.versionsOf($b.meta)[1];
    def page as string init withHead("<head></head>", $b, $de);
    testing.assertContains($page, "<link rel=\"canonical\" href=\"" + SITE_URL + "ada/duo/de/\">");
    testing.assertContains($page, "hreflang=\"en\" href=\"" + SITE_URL + "ada/duo/\">");
    testing.assertContains($page, "hreflang=\"de\" href=\"" + SITE_URL + "ada/duo/de/\">");
    testing.assertContains($page, "hreflang=\"x-default\" href=\"" + SITE_URL + "ada/duo/\">");
    def all as list of Talk init sample();
    $all[] = $b;
    $all = sorted($all);
    def index as string init indexPage($all);
    testing.assertContains($index, "data-langs=\"en de\"");
    testing.assertContains(
        $index,
        "<a class=\"badge\" href=\"ada/duo/\" hreflang=\"en\" title=\"Two languages\">EN</a>");
    testing.assertContains(
        $index,
        "href=\"ada/duo/de/\" hreflang=\"de\" title=\"Zwei Sprachen &lt;de&gt;\">DE</a>");
    testing.assertContains($index, "href=\"ada/duo/de/index.pdf\" hreflang=\"de\"");
    testing.assertContains($index, "href=\"ada/duo/duo.pdf\" hreflang=\"en\"");
    testing.assertContains(
        $index,
        "data-kind=\"lang\" data-value=\"de\" aria-pressed=\"false\">DE</button>");
    testing.assertEqual(langsIn($all), ["de", "en"]);
    # One language in the whole catalogue: no language chips.
    testing.assertFalse(strings.contains(indexPage(sorted(sample())), "data-kind=\"lang\""));
    def map2 as string init sitemap($all);
    testing.assertContains($map2, "xmlns:xhtml=\"http://www.w3.org/1999/xhtml\"");
    testing.assertContains($map2, "<loc>" + SITE_URL + "ada/duo/de/</loc>");
    testing.assertContains(
        $map2,
        "<xhtml:link rel=\"alternate\" hreflang=\"de\" href=\"" + SITE_URL + "ada/duo/de/\"/>");
    testing.assertContains($map2, "<loc>" + SITE_URL + "ada/duo/de/index.pdf</loc>");
    def doc as json.Value init json.decode(catalogue($all));
    testing.assertEqual(json.asString($doc, "/talks/0/topic"), "duo");
    testing.assertEqual(json.length($doc, "/talks/0/versions"), 2);
    testing.assertEqual(json.asString($doc, "/talks/0/versions/1/url"), SITE_URL + "ada/duo/de/");
    testing.assertEqual(json.asString($doc, "/talks/0/versions/1/title"), "Zwei Sprachen <de>");
    testing.assertFalse(json.asBool($doc, "/talks/0/versions/1/primary"));
}

# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * The academy's own pages, as strings: the front page, one page per author
 * and per tag, the legal page, sitemap.xml, robots.txt and talks.json.
 *
 * Everything shown comes from the talks' academy.toml files and is escaped
 * with the `html` module; the JSON-LD and talks.json go through `json`. The
 * pages load nothing from outside the site, and work without JavaScript: the
 * filter chips are the only script, and they start hidden.
 * @module site
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use convert;
use json;
use lists;
use strings;

import "html.j";
import "markdown.j";
import "./meta.j" as meta;

export def const SITE_URL as string init "https://academy.jennifer-lang.dev/";
export def const REPO_URL as string init "https://github.com/jennifer-language/academy";
export def const SITE_TITLE as string init "Jennifer Academy";
export def const LICENSE_URL as string init "https://creativecommons.org/licenses/by/4.0/";
export def const SITE_DESCRIPTION as string init
    "Talks that teach the Jennifer programming language, written by its users as " +
    "slide decks: a slideshow and a PDF for each talk.";

export def const DISCLAIMER as string init
    "<strong>Disclaimer.</strong> The talks are provided as is, without warranty of any " +
    "kind, express or implied, including accuracy, completeness, currency or fitness for a " +
    "particular purpose. Each talk is the work and the responsibility of its author. Use " +
    "the information and code in them at your own risk. To the extent permitted by law, " +
    "the maintainers of the Jennifer project are not liable for any damage arising from " +
    "the use of this site or its talks. Nothing here is legal, financial or professional " +
    "advice.";

def const INTRO as string init
    '<p class="intro">The Jennifer Academy collects talks that teach the Jennifer ' +
    'programming language, written by the people who use it. Each talk is published under ' +
    "its author's GitHub account. Open the slides and move with the arrow keys; on a " +
    'large screen the speaker notes are shown below each slide, <kbd>s</kbd> hides them ' +
    'and <kbd>?</kbd> shows the help. Every talk is also a PDF to read or print.</p>' + "\n";

def const STYLE as string init ':root {
  color-scheme: light dark;
  --bg: #fbf9f7; --fg: #1b1420; --muted: #5d5462; --card: #ffffff;
  --line: #e6dfe3; --accent: #c63d2e; --accent-fg: #ffffff; --chip: #f3ecef;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #1b1420; --fg: #f3eef1; --muted: #b9adb4; --card: #251c2b;
    --line: #3a2e40; --accent: #ec5c4b; --accent-fg: #1b1420; --chip: #30253a;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0; background: var(--bg); color: var(--fg);
  font: 16px/1.55 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
}
a { color: var(--accent); }
kbd { font: 0.85em ui-monospace, monospace; padding: 0.05rem 0.35rem;
  border: 1px solid var(--line); border-radius: 0.3rem; background: var(--card); }
.wrap { max-width: 60rem; margin: 0 auto; padding: 0 16px; }
header { padding: 2.5rem 0 1rem; }
.brand { display: flex; align-items: center; gap: 0.9rem; text-decoration: none; color: inherit; }
.brand img { width: 3rem; height: 3rem; border-radius: 26%;
  box-shadow: 0 0 0 1px var(--line); }
.brand span { font-size: 1.6rem; font-weight: 700; letter-spacing: -0.01em; }
.intro { max-width: 44rem; color: var(--muted); margin-bottom: 0.4rem; }
.links { display: flex; flex-wrap: wrap; gap: 0.3rem 1.1rem; margin: 0; font-size: 0.95rem; }
h1 { font-size: 1.25rem; margin: 2rem 0 1rem; }
.filters { display: flex; flex-wrap: wrap; gap: 0.4rem; margin: 0 0 1rem; }
.filters[hidden] { display: none; }
.filters .label { font-size: 0.85rem; color: var(--muted); align-self: center; }
.chip { font: inherit; font-size: 0.85rem; padding: 0.2rem 0.75rem; border-radius: 999px;
  border: 1px solid var(--line); background: var(--chip); color: var(--fg); cursor: pointer; }
.chip[aria-pressed="true"] { background: var(--accent); color: var(--accent-fg);
  border-color: var(--accent); }
.talks { list-style: none; margin: 0; padding: 0; display: grid; gap: 1rem;
  grid-template-columns: repeat(auto-fill, minmax(17rem, 1fr)); }
.talk { background: var(--card); border: 1px solid var(--line); border-radius: 0.75rem;
  padding: 1.1rem 1.2rem; display: flex; flex-direction: column; gap: 0.5rem; }
.talk[hidden] { display: none; }
.talk h2 { font-size: 1.1rem; margin: 0; line-height: 1.3; }
.talk h2 a { color: inherit; text-decoration: none; }
.talk h2 a:hover { text-decoration: underline; }
.talk p { margin: 0; color: var(--muted); font-size: 0.95rem; overflow-wrap: anywhere; }
.meta { font-size: 0.85rem; color: var(--muted); display: flex; flex-wrap: wrap;
  gap: 0.2rem 0.8rem; }
.tags { list-style: none; margin: 0; padding: 0; display: flex; flex-wrap: wrap; gap: 0.3rem; }
.tags a { font-size: 0.78rem; padding: 0.05rem 0.55rem; border-radius: 999px;
  background: var(--chip); color: var(--fg); text-decoration: none; }
.langs { list-style: none; margin: 0; padding: 0; display: flex; flex-wrap: wrap;
  gap: 0.3rem 0.9rem; font-size: 0.85rem; }
.langs .badge { font: 600 0.75rem ui-monospace, monospace; padding: 0.1rem 0.4rem;
  border-radius: 0.3rem; border: 1px solid var(--accent); text-decoration: none; }
.actions { margin-top: auto; padding-top: 0.4rem; display: flex; gap: 0.6rem; }
.actions a { font-size: 0.9rem; padding: 0.3rem 0.8rem; border-radius: 999px;
  border: 1px solid var(--accent); text-decoration: none; }
.actions a.primary { background: var(--accent); color: var(--accent-fg); }
.empty { color: var(--muted); }
.prose { max-width: 44rem; }
.prose h1 { font-size: 1.5rem; }
.prose h2 { font-size: 1.2rem; margin-top: 2rem; }
footer { margin: 3rem 0 2rem; padding-top: 1rem; border-top: 1px solid var(--line);
  font-size: 0.85rem; color: var(--muted); }
footer .fine { font-size: 0.75rem; }
';

# The filter: chips toggle a level, a tag and a language; a card shows when it
# matches all three.
def const SCRIPT as string init '(function () {
  var box = document.getElementById("filters");
  if (!box) { return; }
  box.hidden = false;
  var on = { level: "", tag: "", lang: "" };
  function has(list, v) { return (" " + list + " ").indexOf(" " + v + " ") >= 0; }
  var cards = document.querySelectorAll(".talks > li");
  var none = document.getElementById("none");
  function apply() {
    var shown = 0;
    cards.forEach(function (c) {
      var ok = (!on.level || c.dataset.level === on.level) &&
        (!on.tag || has(c.dataset.tags, on.tag)) && (!on.lang || has(c.dataset.langs, on.lang));
      c.hidden = !ok;
      if (ok) { shown++; }
    });
    none.hidden = shown > 0;
    box.querySelectorAll(".chip").forEach(function (b) {
      b.setAttribute("aria-pressed", String(on[b.dataset.kind] === b.dataset.value));
    });
  }
  var m = /^#(level|tag|lang)=([a-z0-9-]+)$/.exec(location.hash);
  if (m) { on[m[1]] = m[2]; }
  box.addEventListener("click", function (e) {
    var b = e.target.closest(".chip");
    if (!b) { return; }
    var k = b.dataset.kind;
    on[k] = on[k] === b.dataset.value ? "" : b.dataset.value;
    var h = k && on[k] ? "#" + k + "=" + on[k] : "";
    history.replaceState(null, "", h || location.pathname);
    apply();
  });
  apply();
})();
';

/** A talk in the catalogue: where it lives and its entry. */
export def struct Talk {
    user as string,
    topic as string,
    meta as meta.Meta
};

/** HTML-escape a value. */
func esc(s as string) {
    return html.escape($s);
}

/** The sort key: newest month first (digits inverted), then title. */
func newestFirst(t as Talk) {
    def key as string init "";
    for (def c in strings.chars(meta.latest($t.meta))) {
        def at as int init strings.indexOf("0123456789", $c);
        if ($at < 0) {
            $key = $key + $c;
        } else {
            $key = $key + convert.toString(9 - $at);
        }
    }
    return $key + "\n" + strings.lower($t.meta.title);
}

/**
 * Sort talks newest first (`updated`, else `date`), then by title.
 * @param {list of Talk} talks the talks in any order
 * @return {list of Talk} sorted
 */
export func sorted(talks as list of Talk) {
    return lists.sortBy($talks, newestFirst);
}

/** The path of a talk below the site root, with a trailing slash. */
func talkPath(t as Talk) {
    return $t.user + "/" + $t.topic + "/";
}

/** The PDF's path below the site root (the primary language's). */
func pdfPath(t as Talk) {
    return talkPath($t) + $t.topic + ".pdf";
}

/** A version's slideshow path: the primary at the talk's path, a translation below it. */
func versionPath(t as Talk, v as meta.Version) {
    if ($v.primary) {
        return talkPath($t);
    }
    return talkPath($t) + $v.lang + "/";
}

/** A version's PDF path: `<topic>.pdf` for the primary, `<lang>/index.pdf` otherwise. */
func versionPdf(t as Talk, v as meta.Version) {
    if ($v.primary) {
        return pdfPath($t);
    }
    return versionPath($t, $v) + "index.pdf";
}

/** The languages of a talk, primary first. */
func langsOf(t as Talk) {
    def out as list of string;
    for (def v in meta.versionsOf($t.meta)) {
        $out[] = $v.lang;
    }
    return $out;
}

/** The language badges: each version's code linking its slides, and its PDF. */
func badges(t as Talk, base as string) {
    def out as string init "<ul class=\"langs\">";
    for (def v in meta.versionsOf($t.meta)) {
        def code as string init esc($v.lang);
        def slides as string init esc($base + versionPath($t, $v));
        $out = $out + "<li><a class=\"badge\" href=\"" + $slides + "\" hreflang=\"" + $code;
        $out = $out + "\" title=\"" + esc($v.title) + "\">" + strings.upper($code) + "</a> ";
        $out = $out + "<a href=\"" + esc($base + versionPdf($t, $v)) + "\" hreflang=\"" + $code;
        $out = $out + "\" type=\"application/pdf\">PDF</a></li>";
    }
    return $out + "</ul>\n";
}

/** One talk's card; `base` leads from the page to the site root. */
func card(t as Talk, base as string) {
    def m as meta.Meta init $t.meta;
    def href as string init esc($base + talkPath($t));
    def profile as string init esc(html.safeUrl("https://github.com/" + $m.author));
    def who as string init "<a href=\"" + $profile + "\">@" + esc($m.author) + "</a>";
    if ($m.name != "") {
        $who = esc($m.name) + " (" + $who + ")";
    }
    def tags as string init strings.join($m.tags, " ");
    def langs as string init strings.join(langsOf($t), " ");
    def out as string init "<li class=\"talk\" lang=\"" + esc($m.lang) + "\" data-level=\"";
    $out = $out + esc($m.level) + "\" data-tags=\"" + esc($tags) + "\" data-langs=\"";
    $out = $out + esc($langs) + "\">\n";
    $out = $out + "<h2><a href=\"" + $href + "\">" + esc($m.title) + "</a></h2>\n";
    $out = $out + "<p>" + esc($m.description) + "</p>\n";
    def month as string init esc(meta.latest($m));
    $out = $out + "<div class=\"meta\"><span>" + $who + "</span><span>" + esc($m.level);
    $out = $out + "</span><span>Jennifer " + esc($m.jennifer) + "</span>";
    $out = $out + "<span><time datetime=\"" + $month + "\">" + $month + "</time></span></div>\n";
    $out = $out + "<ul class=\"tags\">";
    for (def tag in $m.tags) {
        def at as string init esc($base + "tags/" + $tag + "/");
        $out = $out + "<li><a href=\"" + $at + "\">" + esc($tag) + "</a></li>";
    }
    $out = $out + "</ul>\n";
    if (len($m.translations) > 0) {
        $out = $out + badges($t, $base);
    }
    $out = $out + "<div class=\"actions\"><a class=\"primary\" href=\"" + $href;
    $out = $out + "\">Slides</a><a href=\"" + esc($base + pdfPath($t));
    $out = $out + "\" type=\"application/pdf\">PDF</a></div>\n</li>\n";
    return $out;
}

/** The list of cards, and the line shown when a filter leaves none. */
func cards(talks as list of Talk, base as string) {
    def out as string init "<ul class=\"talks\">\n";
    for (def t in $talks) {
        $out = $out + card($t, $base);
    }
    return $out + "</ul>\n<p id=\"none\" class=\"empty\" hidden>No talk matches this filter.</p>\n";
}

/** Every tag used, sorted. */
export func tagsOf(talks as list of Talk) {
    def out as list of string;
    for (def t in $talks) {
        for (def tag in $t.meta.tags) {
            if (not lists.contains($out, $tag)) {
                $out[] = $tag;
            }
        }
    }
    return lists.sort($out);
}

/** The filter chips: the levels in use, then the tags. Hidden until the script runs. */
func filters(talks as list of Talk) {
    def out as string init "<div class=\"filters\" id=\"filters\" hidden>";
    $out = $out + "<span class=\"label\">Filter:</span>";
    for (def level in meta.LEVELS) {
        for (def t in $talks) {
            if ($t.meta.level == $level) {
                $out = $out + chip("level", $level);
                break;
            }
        }
    }
    def langs as list of string init langsIn($talks);
    if (len($langs) > 1) {
        $out = $out + "<span class=\"label\">|</span>";
        for (def lang in $langs) {
            $out = $out + chip("lang", $lang);
        }
    }
    $out = $out + "<span class=\"label\">|</span>";
    for (def tag in tagsOf($talks)) {
        $out = $out + chip("tag", $tag);
    }
    return $out + "</div>\n";
}

/** Every language a talk is in, sorted. */
export func langsIn(talks as list of Talk) {
    def out as list of string;
    for (def t in $talks) {
        for (def lang in langsOf($t)) {
            if (not lists.contains($out, $lang)) {
                $out[] = $lang;
            }
        }
    }
    return lists.sort($out);
}

/** One filter chip. */
func chip(kind as string, value as string) {
    def v as string init esc($value);
    def shown as string init $v;
    if ($kind == "lang") {
        $shown = strings.upper($v);
    }
    def out as string init "<button type=\"button\" class=\"chip\" data-kind=\"" + $kind;
    return $out + "\" data-value=\"" + $v + "\" aria-pressed=\"false\">" + $shown + "</button>";
}

/** The JSON-LD description of a list of talks, for search engines. */
export func jsonLd(talks as list of Talk) {
    def items as json.Value init json.list([]);
    def n as int init 0;
    for (def t in $talks) {
        $n = $n + 1;
        def m as meta.Meta init $t.meta;
        def doc as json.Value init json.map({});
        $doc = json.set($doc, "/@type", "PresentationDigitalDocument");
        $doc = json.set($doc, "/name", $m.title);
        $doc = json.set($doc, "/description", $m.description);
        $doc = json.set($doc, "/url", SITE_URL + talkPath($t));
        $doc = json.set($doc, "/inLanguage", $m.lang);
        $doc = json.set($doc, "/license", LICENSE_URL);
        $doc = json.set($doc, "/keywords", strings.join($m.tags, ", "));
        $doc = json.set($doc, "/datePublished", $m.date);
        $doc = json.set($doc, "/dateModified", meta.latest($m));
        $doc = json.set($doc, "/educationalLevel", $m.level);
        def person as json.Value init json.map({});
        $person = json.set($person, "/@type", "Person");
        $person = json.set($person, "/name", authorName($m));
        $person = json.set($person, "/url", "https://github.com/" + $m.author);
        $doc = json.set($doc, "/author", $person);
        def item as json.Value init json.map({});
        $item = json.set($item, "/@type", "ListItem");
        $item = json.set($item, "/position", $n);
        $item = json.set($item, "/item", $doc);
        $items = json.append($items, "", $item);
    }
    def all as json.Value init json.map({});
    $all = json.set($all, "/@context", "https://schema.org");
    $all = json.set($all, "/@type", "ItemList");
    $all = json.set($all, "/itemListElement", $items);
    # json.encode escapes < > & as < ..., so the text cannot close the script.
    return "<script type=\"application/ld+json\">" + json.encode($all) + "</script>\n";
}

/** The author's display name: the name when given, else @login. */
func authorName(m as meta.Meta) {
    if ($m.name != "") {
        return $m.name;
    }
    return "@" + $m.author;
}

/** The page's header and footer around `body`. */
func page(
    title as string,
    description as string,
    keywords as string,
    canonical as string,
    base as string,
    body as string) {
    def b as string init esc($base);
    def head as string init "<!doctype html>\n<html lang=\"en\">\n<head>\n";
    $head = $head + "<meta charset=\"utf-8\">\n";
    $head = $head + "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n";
    $head = $head + "<title>" + esc($title) + "</title>\n";
    $head = $head + "<meta name=\"description\" content=\"" + esc($description) + "\">\n";
    $head = $head + "<meta name=\"keywords\" content=\"" + esc($keywords) + "\">\n";
    $head = $head + "<link rel=\"canonical\" href=\"" + esc($canonical) + "\">\n";
    $head = $head + "<meta property=\"og:title\" content=\"" + esc($title) + "\">\n";
    $head = $head + "<meta property=\"og:description\" content=\"" + esc($description) + "\">\n";
    $head = $head + "<meta property=\"og:url\" content=\"" + esc($canonical) + "\">\n";
    $head = $head + "<meta property=\"og:type\" content=\"website\">\n";
    $head = $head + "<link rel=\"icon\" href=\"" + $b + "jennifer.svg\" type=\"image/svg+xml\">\n";
    $head = $head + "<style>\n" + STYLE + "</style>\n</head>\n<body>\n<div class=\"wrap\">\n";
    def top as string init "<header><a class=\"brand\" href=\"" + $b + "\"><img src=\"" + $b;
    $top = $top + "jennifer.svg\" alt=\"\" width=\"48\" height=\"48\"><span>" + SITE_TITLE;
    $top = $top + "</span></a></header>\n";
    def foot as string init "<footer>\n<p>Talks are licensed under CC BY 4.0 by their authors. ";
    $foot = $foot + "<a href=\"" + REPO_URL + "\">Source and contributions</a> · ";
    $foot = $foot + "<a href=\"https://jennifer-lang.dev/\">jennifer-lang.dev</a> · ";
    $foot = $foot + "<a href=\"" + $b + "legal/\">Legal</a></p>\n";
    $foot = $foot + "<p class=\"fine\">" + DISCLAIMER + "</p>\n</footer>\n</div>\n";
    return $head + $top + "<main>\n" + $body + "</main>\n" + $foot;
}

/** The end of a page: the filter script when there are chips, then the closing tags. */
func pageEnd(withScript as bool) {
    if ($withScript) {
        return "<script>\n" + SCRIPT + "</script>\n</body>\n</html>\n";
    }
    return "</body>\n</html>\n";
}

/** The keywords of a page: the site's own plus every tag. */
func keywordsOf(talks as list of Talk) {
    def words as list of string init [
        "jennifer",
        "programming language",
        "talks",
        "slides",
        "teaching"
    ];
    for (def tag in tagsOf($talks)) {
        if (not lists.contains($words, $tag)) {
            $words[] = $tag;
        }
    }
    return strings.join($words, ", ");
}

/**
 * The front page: the intro, the filter chips and every talk.
 * @param {list of Talk} talks sorted talks
 * @return {string} index.html
 */
export func indexPage(talks as list of Talk) {
    def links as string init "<p class=\"links\"><a href=\"" + REPO_URL +
        "/blob/main/CONTRIBUTING.md\">";
    $links = $links +
        "Contribute a talk</a><a href=\"https://jennifer-lang.dev/\">jennifer-lang.dev</a>";
    $links = $links + "<a href=\"https://docs.jennifer-lang.dev/\">Documentation</a>";
    $links = $links + "<a href=\"talks.json\">talks.json</a></p>\n";
    def body as string init INTRO + $links + "<h1>Talks</h1>\n" + filters($talks) +
        cards($talks, "");
    $body = $body + jsonLd($talks);
    def out as string init page(
        SITE_TITLE,
        SITE_DESCRIPTION,
        keywordsOf($talks),
        SITE_URL,
        "",
        $body);
    return $out + pageEnd(true);
}

/** Only the talks with this author. */
func byUser(talks as list of Talk, user as string) {
    def out as list of Talk;
    for (def t in $talks) {
        if ($t.user == $user) {
            $out[] = $t;
        }
    }
    return $out;
}

/** Only the talks with this tag. */
func byTag(talks as list of Talk, tag as string) {
    def out as list of Talk;
    for (def t in $talks) {
        if (lists.contains($t.meta.tags, $tag)) {
            $out[] = $t;
        }
    }
    return $out;
}

/**
 * One author's page, `/<user>/`.
 * @param {list of Talk} talks all sorted talks
 * @param {string} user the namespace
 * @return {string} index.html
 */
export func userPage(talks as list of Talk, user as string) {
    def mine as list of Talk init byUser($talks, $user);
    def profile as string init esc(html.safeUrl("https://github.com/" + $user));
    def body as string init "<h1>Talks by <a href=\"" + $profile + "\">@" + esc($user) +
        "</a></h1>\n";
    $body = $body + cards($mine, "../") + jsonLd($mine);
    def description as string init "Talks about the Jennifer programming language by @" + $user +
        ".";
    def title as string init "@" + $user + " - " + SITE_TITLE;
    return page($title, $description, keywordsOf($mine), SITE_URL + $user + "/", "../", $body) +
        pageEnd(false);
}

/**
 * One tag's page, `/tags/<tag>/`.
 * @param {list of Talk} talks all sorted talks
 * @param {string} tag the tag
 * @return {string} index.html
 */
export func tagPage(talks as list of Talk, tag as string) {
    def mine as list of Talk init byTag($talks, $tag);
    def body as string init "<h1>Talks tagged " + esc($tag) + "</h1>\n" + cards($mine, "../../") +
        jsonLd($mine);
    def description as string init "Talks about the Jennifer programming language tagged " + $tag +
        ".";
    def url as string init SITE_URL + "tags/" + $tag + "/";
    def title as string init $tag + " - " + SITE_TITLE;
    return page($title, $description, keywordsOf($mine), $url, "../../", $body) + pageEnd(false);
}

/**
 * The legal page, from legal.md, with the disclaimer as its own section.
 * @param {string} source legal.md
 * @return {string} legal/index.html
 */
export func legalPage(source as string) {
    def body as string init "<div class=\"prose\">\n" + markdown.toHtml($source);
    $body = $body + "\n<h2>Disclaimer</h2>\n<p>" + DISCLAIMER + "</p>\n</div>\n";
    def description as string init "Responsibility, reporting and disclaimer: Jennifer Academy.";
    def url as string init SITE_URL + "legal/";
    return page(
        "Legal - " + SITE_TITLE,
        $description,
        "jennifer, academy, legal, disclaimer",
        $url,
        "../",
        $body) + pageEnd(false);
}

/** One sitemap entry. */
func loc(url as string, month as string) {
    if ($month == "") {
        return "<url><loc>" + esc($url) + "</loc></url>\n";
    }
    return "<url><loc>" + esc($url) + "</loc><lastmod>" + esc($month) + "</lastmod></url>\n";
}

/**
 * sitemap.xml: the front page, the authors, the tags, the legal page, every talk and PDF.
 * @param {list of Talk} talks all sorted talks
 * @return {string} the sitemap
 */
export func sitemap(talks as list of Talk) {
    def out as string init '<?xml version="1.0" encoding="UTF-8"?>' + "\n";
    $out = $out + '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" ';
    $out = $out + 'xmlns:xhtml="http://www.w3.org/1999/xhtml">' + "\n";
    $out = $out + loc(SITE_URL, "");
    def users as list of string;
    for (def t in $talks) {
        if (not lists.contains($users, $t.user)) {
            $users[] = $t.user;
            $out = $out + loc(SITE_URL + $t.user + "/", "");
        }
    }
    for (def t in $talks) {
        def month as string init meta.latest($t.meta);
        def alt as string init alternatesXml($t);
        for (def v in meta.versionsOf($t.meta)) {
            def url as string init esc(SITE_URL + versionPath($t, $v));
            $out = $out + "<url><loc>" + $url + "</loc><lastmod>" + esc($month) + "</lastmod>";
            $out = $out + $alt + "</url>\n" + loc(SITE_URL + versionPdf($t, $v), $month);
        }
    }
    for (def tag in tagsOf($talks)) {
        $out = $out + loc(SITE_URL + "tags/" + $tag + "/", "");
    }
    return $out + loc(SITE_URL + "legal/", "") + "</urlset>\n";
}

/** The sitemap's `xhtml:link` alternates of a talk: every version, and x-default. */
func alternatesXml(t as Talk) {
    def out as string init "";
    for (def v in meta.versionsOf($t.meta)) {
        $out = $out + "<xhtml:link rel=\"alternate\" hreflang=\"" + esc($v.lang) + "\" href=\"";
        $out = $out + esc(SITE_URL + versionPath($t, $v)) + "\"/>";
    }
    $out = $out + "<xhtml:link rel=\"alternate\" hreflang=\"x-default\" href=\"";
    return $out + esc(SITE_URL + talkPath($t)) + "\"/>";
}

/**
 * robots.txt: everything may be crawled; the sitemap is named.
 * @return {string} the file
 */
export func robots() {
    return "User-agent: *\nAllow: /\n\nSitemap: " + SITE_URL + "sitemap.xml\n";
}

/**
 * talks.json: the merged catalogue (shape in the README).
 * @param {list of Talk} talks all sorted talks
 * @return {string} pretty-printed JSON
 */
export func catalogue(talks as list of Talk) {
    def list2 as json.Value init json.list([]);
    for (def t in $talks) {
        def m as meta.Meta init $t.meta;
        def doc as json.Value init json.map({});
        $doc = json.set($doc, "/author", $m.author);
        $doc = json.set($doc, "/name", $m.name);
        $doc = json.set($doc, "/topic", $t.topic);
        $doc = json.set($doc, "/title", $m.title);
        $doc = json.set($doc, "/description", $m.description);
        $doc = json.set($doc, "/license", $m.license);
        $doc = json.set($doc, "/lang", $m.lang);
        $doc = json.set($doc, "/jennifer", $m.jennifer);
        $doc = json.set($doc, "/date", $m.date);
        $doc = json.set($doc, "/updated", $m.updated);
        $doc = json.set($doc, "/level", $m.level);
        $doc = json.set($doc, "/tags", $m.tags);
        $doc = json.set($doc, "/url", SITE_URL + talkPath($t));
        $doc = json.set($doc, "/pdf", SITE_URL + pdfPath($t));
        def versions as json.Value init json.list([]);
        for (def v in meta.versionsOf($m)) {
            def one as json.Value init json.map({});
            $one = json.set($one, "/lang", $v.lang);
            $one = json.set($one, "/primary", $v.primary);
            $one = json.set($one, "/title", $v.title);
            $one = json.set($one, "/description", $v.description);
            $one = json.set($one, "/url", SITE_URL + versionPath($t, $v));
            $one = json.set($one, "/pdf", SITE_URL + versionPdf($t, $v));
            $versions = json.append($versions, "", $one);
        }
        $doc = json.set($doc, "/versions", $versions);
        $list2 = json.append($list2, "", $doc);
    }
    def all as json.Value init json.map({});
    $all = json.set($all, "/version", 1);
    $all = json.set($all, "/site", SITE_URL);
    $all = json.set($all, "/talks", $list2);
    return json.encodePretty($all) + "\n";
}

/**
 * Add what cantrip does not write to one version's slideshow: its canonical
 * link, and an `hreflang` alternate for every version plus `x-default`.
 * @param {string} page the slideshow's HTML
 * @param {Talk} t the talk
 * @param {meta.Version} v the version this page is
 * @return {string} the HTML with the links right after `<head>`
 */
export func withHead(page as string, t as Talk, v as meta.Version) {
    if (not strings.contains($page, "<head>")) {
        return $page;
    }
    def links as string init "<head>\n<link rel=\"canonical\" href=\"" +
        esc(SITE_URL + versionPath($t, $v)) + "\">";
    for (def other in meta.versionsOf($t.meta)) {
        $links = $links + "\n<link rel=\"alternate\" hreflang=\"" + esc($other.lang) + "\" href=\"";
        $links = $links + esc(SITE_URL + versionPath($t, $other)) + "\">";
    }
    $links = $links + "\n<link rel=\"alternate\" hreflang=\"x-default\" href=\"";
    $links = $links + esc(SITE_URL + talkPath($t)) + "\">";
    def at as int init strings.indexOf($page, "<head>");
    return strings.substring($page, 0, $at) + $links + strings.substring(
        $page,
        $at + 6,
        len($page));
}

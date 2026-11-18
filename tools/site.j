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
 * filter bar is the only script, and it starts hidden.
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
  --beginner: #23784a; --beginner-bg: #e3f3e9;
  --intermediate: #1d65a6; --intermediate-bg: #e2edf8;
  --advanced: #8a3aa3; --advanced-bg: #f2e6f6;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #1b1420; --fg: #f3eef1; --muted: #b9adb4; --card: #251c2b;
    --line: #3a2e40; --accent: #ec5c4b; --accent-fg: #1b1420; --chip: #30253a;
    --beginner: #6fd09a; --beginner-bg: #1d3328;
    --intermediate: #72b4f0; --intermediate-bg: #1c2c3f;
    --advanced: #cf93ea; --advanced-bg: #33223d;
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
.wrap { max-width: 112rem; margin: 0 auto; padding: 0 16px; }
@media (min-width: 60rem) { .wrap { padding: 0 2rem; } }
header { padding: 2rem 0 1rem; display: flex; flex-wrap: wrap; align-items: center;
  gap: 1rem 1.5rem; }
.search { flex: 0 1 36rem; margin: 0 0 0 auto; }
@media (max-width: 40rem) { .search { flex: 1 1 100%; } }
.search input { width: 100%; font: inherit; font-size: 1.05rem; color: var(--fg);
  background: var(--card); border: 1px solid var(--line); border-radius: 999px;
  height: 2.9rem; padding: 0 1.2rem; }
.search input:focus-visible { outline: 2px solid var(--accent); outline-offset: 1px; }
.brand { display: flex; align-items: center; gap: 0.9rem; text-decoration: none; color: inherit; }
.brand img { width: 3rem; height: 3rem; border-radius: 26%;
  box-shadow: 0 0 0 1px var(--line); }
.brand span { font-size: 1.6rem; font-weight: 700; letter-spacing: -0.01em; }
.intro { max-width: 44rem; color: var(--muted); margin-bottom: 0.4rem; }
.links { display: flex; flex-wrap: wrap; gap: 0.3rem 1.1rem; margin: 0; font-size: 0.95rem; }
.lead { display: flex; flex-wrap: wrap; align-items: flex-start; gap: 1.5rem 3rem; }
.lead > div { flex: 1 1 28rem; max-width: 44rem; }
.lead .intro { margin-top: 0; }
.bylevel { flex: 1 1 30rem; display: grid; gap: 0.7rem;
  grid-template-columns: repeat(auto-fit, minmax(9.5rem, 1fr)); }
.bylevel a { --level: var(--muted); --level-bg: var(--chip);
  display: flex; flex-direction: column; gap: 0.15rem; text-decoration: none; color: var(--fg);
  background: var(--card); border: 1px solid var(--line); border-left: 4px solid var(--level);
  border-radius: 0.6rem; padding: 0.6rem 0.9rem; }
.bylevel a.beginner { --level: var(--beginner); }
.bylevel a.intermediate { --level: var(--intermediate); }
.bylevel a.advanced { --level: var(--advanced); }
.bylevel a:hover { box-shadow: 0 0 0 1px var(--level); }
.bylevel strong { color: var(--level); font-size: 1rem; }
.bylevel .n { font-size: 1.5rem; font-weight: 700; line-height: 1.2; }
.bylevel .who { font-size: 0.8rem; color: var(--muted); }
@media (max-width: 40rem) {
  .bylevel { grid-template-columns: 1fr; gap: 0.5rem; }
  .bylevel a { display: grid; grid-template-columns: auto 1fr; align-items: baseline;
    gap: 0.1rem 0.8rem; padding: 0.5rem 0.8rem; }
  .bylevel .n { font-size: 1rem; justify-self: end; }
  .bylevel .who { grid-column: 1 / -1; }
}
.pagenav { display: flex; flex-wrap: wrap; align-items: center; gap: 0.3rem 1rem;
  margin: 0.8rem 0 1.4rem; font-size: 0.95rem; }
h1 + .pagenav { margin-top: -0.3rem; }
.pagenav .count { margin: 0; line-height: inherit; color: var(--muted); }
.pagenav [aria-current] { font-weight: 600; }
h1 { font-size: 1.25rem; margin: 2rem 0 1rem; }
.filters { display: flex; flex-wrap: wrap; align-items: flex-end; gap: 0.6rem 0.8rem;
  margin: 0 0 1.2rem; padding: 0.8rem 1rem; background: var(--card);
  border: 1px solid var(--line); border-radius: 0.75rem; }
.filters[hidden] { display: none; }
.field { display: flex; flex-direction: column; gap: 0.2rem; font-size: 0.8rem;
  color: var(--muted); min-width: 0; }
.field input, .field select { font: inherit; font-size: 0.95rem; color: var(--fg);
  background: var(--bg); border: 1px solid var(--line); border-radius: 0.45rem;
  height: 2.3rem; padding: 0 0.55rem; min-width: 0; max-width: 100%; }
.field input:focus-visible, .field select:focus-visible, .reset:focus-visible {
  outline: 2px solid var(--accent); outline-offset: 1px; }
.reset { font: inherit; font-size: 0.9rem; height: 2.3rem; padding: 0 0.9rem; border-radius: 999px;
  border: 1px solid var(--line); background: var(--chip); color: var(--fg); cursor: pointer; }
.count { margin: 0 0 0 auto; font-size: 0.85rem; color: var(--muted); line-height: 2.3rem; }
.talks { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.9rem;
  grid-template-columns: repeat(auto-fill, minmax(16rem, 1fr)); }
.talk { --level: var(--muted); --level-bg: var(--chip);
  background: var(--card); border: 1px solid var(--line); border-top: 4px solid var(--level);
  border-radius: 0.75rem; padding: 0.9rem 1.1rem 1rem;
  display: flex; flex-direction: column; gap: 0.45rem; }
.talk.beginner { --level: var(--beginner); --level-bg: var(--beginner-bg); }
.talk.intermediate { --level: var(--intermediate); --level-bg: var(--intermediate-bg); }
.talk.advanced { --level: var(--advanced); --level-bg: var(--advanced-bg); }
.talk[hidden] { display: none; }
.level { align-self: flex-start; text-decoration: none; font-size: 0.72rem; font-weight: 700;
  letter-spacing: 0.04em; text-transform: uppercase; padding: 0.1rem 0.5rem; border-radius: 999px;
  color: var(--level); background: var(--level-bg); }
a.level:hover { text-decoration: underline; }
.talk h2 { font-size: 1.05rem; margin: 0; line-height: 1.3; }
.talk h2 a { color: inherit; text-decoration: none; }
.talk h2 a:hover { text-decoration: underline; }
.talk p { margin: 0; color: var(--muted); font-size: 0.9rem; overflow-wrap: anywhere;
  display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 3;
  line-clamp: 3; overflow: hidden; }
.meta { font-size: 0.8rem; color: var(--muted); display: flex; flex-wrap: wrap;
  gap: 0.2rem 0.8rem; }
.tags { list-style: none; margin: 0; padding: 0; display: flex; flex-wrap: wrap; gap: 0.3rem; }
.tags a { font-size: 0.75rem; padding: 0.05rem 0.5rem; border-radius: 999px;
  background: var(--chip); color: var(--fg); text-decoration: none; }
.tags .current { display: inline-block; font-size: 0.75rem; font-weight: 600;
  padding: 0.05rem 0.5rem; border-radius: 999px; background: var(--accent);
  color: var(--accent-fg); }
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

# The live search: the search box in the header and the filter bar's dropdowns
# (level, topic and, with several languages, language). A card shows when it
# matches every dropdown and contains every word searched for, in its title,
# description, level, tags or author. The choice is kept in the address as a
# query (?q=...&level=...&tag=...), the same one the header's form submits from
# other pages and the search engines' SearchAction names.
def const SCRIPT as string init '(function () {
  var box = document.getElementById("filters");
  var search = document.getElementById("filter-q");
  if (!box || !search) { return; }
  box.hidden = false;
  var selects = box.querySelectorAll("select[data-kind]");
  var sort = box.querySelector("select[data-sort]");
  var cards = Array.prototype.slice.call(document.querySelectorAll(".talks > li"));
  cards.forEach(function (c, i) { c.dataset.at = i; });
  function title(c) { return c.querySelector("h2").textContent.toLowerCase(); }
  function order() {
    var how = sort.value;
    cards.slice().sort(function (a, b) {
      if (how === "newest" && a.dataset.month !== b.dataset.month) {
        return a.dataset.month < b.dataset.month ? 1 : -1;
      }
      if (how !== "level") { return title(a) < title(b) ? -1 : title(a) > title(b) ? 1 : 0; }
      return a.dataset.at - b.dataset.at;
    }).forEach(function (c) { c.parentNode.appendChild(c); });
  }
  var none = document.getElementById("none");
  var count = document.getElementById("count");
  function has(list, v) { return (" " + list + " ").indexOf(" " + v + " ") >= 0; }
  function chosen(kind) {
    var s = box.querySelector("select[data-kind=\"" + kind + "\"]");
    return s ? s.value : "";
  }
  function talks(n) { return n + (n === 1 ? " talk" : " talks"); }
  function apply() {
    var level = chosen("level"), tag = chosen("tag"), lang = chosen("lang");
    var words = search.value.toLowerCase().split(/\s+/).filter(Boolean);
    var shown = 0;
    cards.forEach(function (c) {
      var text = c.textContent.toLowerCase();
      var ok = (!level || c.dataset.level === level) && (!tag || has(c.dataset.tags, tag)) &&
        (!lang || has(c.dataset.langs, lang)) &&
        words.every(function (w) { return text.indexOf(w) >= 0; });
      c.hidden = !ok;
      if (ok) { shown++; }
    });
    none.hidden = shown > 0;
    count.textContent = shown === cards.length ? talks(shown) :
      shown + " of " + talks(cards.length);
    var p = new URLSearchParams();
    if (search.value.trim()) { p.set("q", search.value.trim()); }
    selects.forEach(function (s) { if (s.value) { p.set(s.dataset.kind, s.value); } });
    if (sort.value !== "level") { p.set("sort", sort.value); }
    var q = p.toString();
    history.replaceState(null, "", location.pathname + (q ? "?" + q : ""));
  }
  var start = new URLSearchParams(location.search || location.hash.slice(1));
  selects.forEach(function (s) {
    var v = start.get(s.dataset.kind);
    if (!v || !/^[a-z0-9-]+$/.test(v)) { return; }
    var found = false;
    for (var i = 0; i < s.options.length; i++) {
      if (s.options[i].value === v) { found = true; }
    }
    // A topic of one talk is not in the list, but a link to it still works.
    if (!found && s.dataset.kind === "tag" &&
        document.querySelector(".talks > li[data-tags~=\"" + v + "\"]")) {
      s.add(new Option(v, v));
      found = true;
    }
    if (found) { s.value = v; }
  });
  search.value = start.get("q") || "";
  if (["newest", "title"].indexOf(start.get("sort")) >= 0) { sort.value = start.get("sort"); }
  sort.addEventListener("change", order);
  order();
  search.form.addEventListener("submit", function (e) { e.preventDefault(); apply(); });
  search.addEventListener("input", apply);
  box.addEventListener("change", apply);
  box.addEventListener("submit", function (e) { e.preventDefault(); });
  box.addEventListener("reset", function () {
    search.value = "";
    setTimeout(function () { order(); apply(); }, 0);
  });
  apply();
})();
';

/**
 * How many talks a topic needs to be offered in the filter bar. Rarer topics
 * keep their tag page, their link on the card and the search; listing every one
 * would make the dropdown longer than the list of talks.
 */
def const TOPIC_MIN as int init 2;

/**
 * A talk in the catalogue: where it lives, its entry, and the day its
 * directory last changed in git (`YYYY-MM-DD`, "" when unknown).
 */
export def struct Talk {
    user as string,
    topic as string,
    meta as meta.Meta,
    modified as string
};

/**
 * When the published talk last changed, for machines: the git day when known,
 * else the author's month (`updated`, else `date`). Readers see the month.
 */
export func modifiedOf(t as Talk) {
    if ($t.modified != "") {
        return $t.modified;
    }
    return meta.latest($t.meta);
}

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

/** The display key: the level in the order of meta.LEVELS, then the title. */
func levelFirst(t as Talk) {
    def at as int init lists.indexOf(meta.LEVELS, $t.meta.level);
    return convert.toString($at) + "\n" + strings.lower($t.meta.title);
}

/**
 * Order talks for a list page: beginner first, then intermediate, then
 * advanced, each by title, so the colours form bands.
 * @param {list of Talk} talks the talks in any order
 * @return {list of Talk} sorted
 */
export func shown(talks as list of Talk) {
    return lists.sortBy($talks, levelFirst);
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
func card(t as Talk, base as string, withLevel as bool, currentTag as string) {
    def m as meta.Meta init $t.meta;
    def href as string init esc($base + talkPath($t));
    def profile as string init esc(html.safeUrl("https://github.com/" + $m.author));
    def who as string init "<a href=\"" + $profile + "\">@" + esc($m.author) + "</a>";
    if ($m.name != "") {
        $who = esc($m.name) + " (" + $who + ")";
    }
    def tags as string init strings.join($m.tags, " ");
    def langs as string init strings.join(langsOf($t), " ");
    def out as string init "<li class=\"talk " + esc($m.level) + "\" lang=\"" + esc($m.lang);
    $out = $out + "\" data-level=\"";
    $out = $out + esc($m.level) + "\" data-tags=\"" + esc($tags) + "\" data-langs=\"";
    $out = $out + esc($langs) + "\" data-month=\"" + esc(meta.latest($m)) + "\">\n";
    if ($withLevel) {
        $out = $out + "<a class=\"level\" href=\"" + esc($base + "levels/" + $m.level + "/");
        $out = $out + "\">" + esc(levelName($m.level)) + "</a>\n";
    }
    $out = $out + "<h2><a href=\"" + $href + "\">" + esc($m.title) + "</a></h2>\n";
    $out = $out + "<p>" + esc($m.description) + "</p>\n";
    def month as string init esc(meta.latest($m));
    $out = $out + "<div class=\"meta\"><span>" + $who + "</span>";
    $out = $out + "<span>Jennifer " + esc($m.jennifer) + "</span>";
    $out = $out + "<span><time datetime=\"" + $month + "\">" + $month + "</time></span></div>\n";
    $out = $out + "<ul class=\"tags\">";
    for (def tag in $m.tags) {
        if ($tag == $currentTag) {
            $out = $out + "<li><span class=\"current\" aria-current=\"page\">" + esc($tag) +
                "</span></li>";
            continue;
        }
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

/**
 * The list of cards, and the line shown when a filter leaves none. A level's
 * own page leaves the level label off: there every card has the same one. A
 * tag's page marks its tag on each card instead of linking it to itself.
 */
func cards(talks as list of Talk, base as string, withLevel as bool, currentTag as string) {
    def out as string init "<ul class=\"talks\">\n";
    for (def t in shown($talks)) {
        $out = $out + card($t, $base, $withLevel, $currentTag);
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

/** A level as shown: "beginner" becomes "Beginner". */
func levelName(level as string) {
    if ($level == "") {
        return "";
    }
    return strings.upper($level[0..1]) + $level[1..];
}

/**
 * The filter bar under the header's search box: a dropdown of the levels in
 * use, of the tags at least TOPIC_MIN talks share and, with several languages,
 * of the languages, each option with its number
 * of talks. Hidden until the script runs, so without it every talk shows.
 */
func filters(talks as list of Talk) {
    def out as string init "<form class=\"filters\" id=\"filters\" hidden>\n";
    def levels as list of string;
    for (def level in meta.LEVELS) {
        def n as int init 0;
        for (def t in $talks) {
            if ($t.meta.level == $level) {
                $n = $n + 1;
            }
        }
        if ($n > 0) {
            $levels[] = option($level, levelName($level), $n);
        }
    }
    $out = $out + dropdown("level", "Level", "All levels", $levels);
    def tags as list of string;
    for (def tag in tagsOf($talks)) {
        def n as int init len(byTag($talks, $tag));
        if ($n >= TOPIC_MIN) {
            $tags[] = option($tag, $tag, $n);
        }
    }
    $out = $out + dropdown("tag", "Topic", "All topics", $tags);
    def langs as list of string init langsIn($talks);
    if (len($langs) > 1) {
        def items as list of string;
        for (def lang in $langs) {
            def n as int init 0;
            for (def t in $talks) {
                if (lists.contains(langsOf($t), $lang)) {
                    $n = $n + 1;
                }
            }
            $items[] = option($lang, strings.upper($lang), $n);
        }
        $out = $out + dropdown("lang", "Language", "All languages", $items);
    }
    $out = $out + "<label class=\"field\">Sort<select data-sort>";
    $out = $out +
        "<option value=\"level\">By level</option><option value=\"newest\">Newest first</option>";
    $out = $out + "<option value=\"title\">By title</option></select></label>\n";
    $out = $out + "<button type=\"reset\" class=\"reset\">Reset</button>\n";
    return $out + "<p class=\"count\" id=\"count\" aria-live=\"polite\"></p>\n</form>\n";
}

/** One labelled dropdown of the filter bar, its first option meaning "any". */
func dropdown(kind as string, label as string, any as string, options as list of string) {
    def out as string init "<label class=\"field\">" + $label + "<select data-kind=\"" + $kind;
    $out = $out + "\"><option value=\"\">" + $any + "</option>";
    return $out + strings.join($options, "") + "</select></label>\n";
}

/** One dropdown option: the value, the text shown and how many talks have it. */
func option(value as string, shown as string, n as int) {
    return "<option value=\"" + esc($value) + "\">" + esc($shown) + " (" + convert.toString($n) +
        ")</option>";
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

/** The JSON-LD description of a list of talks, for search engines. */
export func jsonLd(talks as list of Talk) {
    def items as json.Value init json.list([]);
    def n as int init 0;
    for (def t in shown($talks)) {
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
        $doc = json.set($doc, "/dateModified", modifiedOf($t));
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
    $top = $top + "</span></a>\n<form class=\"search\" action=\"" + $b + "\" method=\"get\" ";
    $top = $top + "role=\"search\"><input type=\"search\" name=\"q\" id=\"filter-q\" ";
    $top = $top + "placeholder=\"Search talks: topic, keyword, level\" ";
    $top = $top + "aria-label=\"Search talks\" autocomplete=\"off\"></form>\n</header>\n";
    def foot as string init "<footer>\n<p>Talks are licensed under CC BY 4.0 by their authors. ";
    $foot = $foot + "<a href=\"" + REPO_URL + "\">Source and contributions</a> · ";
    $foot = $foot + "<a href=\"https://jennifer-lang.dev/\">jennifer-lang.dev</a> · ";
    $foot = $foot + "<a href=\"" + $b + "legal/\">Legal</a></p>\n";
    $foot = $foot + "<p class=\"fine\">" + DISCLAIMER + "</p>\n</footer>\n</div>\n";
    return $head + $top + "<main>\n" + $body + "</main>\n" + $foot;
}

/** The end of a page: the filter script on the front page, then the closing tags. */
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
 * The front page: the intro, the filter bar and every talk.
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
    def body as string init "<div class=\"lead\"><div>\n" + INTRO + $links + "</div>\n" +
        levelBoxes($talks) + "</div>\n<h1>Talks</h1>\n" + filters($talks) +
        cards($talks, "", true, "");
    $body = $body + websiteLd() + jsonLd($talks);
    def out as string init page(
        SITE_TITLE,
        SITE_DESCRIPTION,
        keywordsOf($talks),
        SITE_URL,
        "",
        $body);
    return $out + pageEnd(true);
}

/**
 * The site as a schema.org WebSite whose SearchAction is the front page's
 * `?q=` search, so a search engine can offer it.
 */
func websiteLd() {
    def target as json.Value init json.map({});
    $target = json.set($target, "/@type", "EntryPoint");
    $target = json.set($target, "/urlTemplate", SITE_URL + '?q={search_term_string}');
    def action as json.Value init json.map({});
    $action = json.set($action, "/@type", "SearchAction");
    $action = json.set($action, "/target", $target);
    $action = json.set($action, "/query-input", "required name=search_term_string");
    def doc as json.Value init json.map({});
    $doc = json.set($doc, "/@context", "https://schema.org");
    $doc = json.set($doc, "/@type", "WebSite");
    $doc = json.set($doc, "/name", SITE_TITLE);
    $doc = json.set($doc, "/url", SITE_URL);
    $doc = json.set($doc, "/potentialAction", $action);
    return "<script type=\"application/ld+json\">" + json.encode($doc) + "</script>\n";
}

/** Only the talks of this level. */
func byLevel(talks as list of Talk, level as string) {
    def out as list of Talk;
    for (def t in $talks) {
        if ($t.meta.level == $level) {
            $out[] = $t;
        }
    }
    return $out;
}

/** Every level that has a talk, in the order of meta.LEVELS. */
export func levelsOf(talks as list of Talk) {
    def out as list of string;
    for (def level in meta.LEVELS) {
        if (len(byLevel($talks, $level)) > 0) {
            $out[] = $level;
        }
    }
    return $out;
}

/** Who a level's talks are for, one sentence for its page. */
func levelIntro(level as string) {
    if ($level == "beginner") {
        return "Talks for people new to Jennifer, or new to programming.";
    }
    if ($level == "intermediate") {
        return "Talks for people who write Jennifer and want to build real programs with it.";
    }
    return "Talks that go deep: the language's corners, its runtime and larger systems.";
}

/** "1 talk", "4 talks". */
func talksCount(n as int) {
    if ($n == 1) {
        return "1 talk";
    }
    return convert.toString($n) + " talks";
}

/**
 * The front page's level boxes beside the intro: each level in use, coloured
 * like its cards, with its number of talks and who it is for, linking its page.
 */
func levelBoxes(talks as list of Talk) {
    def out as string init "<nav class=\"bylevel\" aria-label=\"Talks by level\">";
    for (def level in levelsOf($talks)) {
        def l as string init esc($level);
        $out = $out + "<a class=\"" + $l + "\" href=\"levels/" + $l + "/\"><strong>" +
            esc(levelName($level)) + "</strong><span class=\"n\">" +
            talksCount(len(byLevel($talks, $level))) + "</span><span class=\"who\">" +
            esc(levelIntro($level)) + "</span></a>";
    }
    return $out + "</nav>\n";
}

/**
 * The line under a level page's intro: how many talks it lists, then links to
 * all talks and to the other levels, the current one marked, not linked.
 */
func levelNav(talks as list of Talk, level as string, n as int) {
    def out as string init "<nav class=\"pagenav\" aria-label=\"Levels\"><p class=\"count\">" +
        talksCount($n) + "</p><a href=\"../../\">All talks</a>";
    for (def other in levelsOf($talks)) {
        if ($other == $level) {
            $out = $out + "<span aria-current=\"page\">" + esc(levelName($other)) + "</span>";
        } else {
            $out = $out + "<a href=\"../" + esc($other) + "/\">" + esc(levelName($other)) + "</a>";
        }
    }
    return $out + "</nav>\n";
}

/**
 * One level's page, `/levels/<level>/`.
 * @param {list of Talk} talks all sorted talks
 * @param {string} level one of meta.LEVELS
 * @return {string} index.html
 */
export func levelPage(talks as list of Talk, level as string) {
    def mine as list of Talk init byLevel($talks, $level);
    def name as string init levelName($level);
    def body as string init "<h1>" + esc($name) + " talks</h1>\n<p class=\"intro\">" +
        esc(levelIntro($level)) + "</p>\n" + levelNav($talks, $level, len($mine)) +
        cards($mine, "../../", false, "") + jsonLd($mine);
    def description as string init $name + " talks about the Jennifer programming language. " +
        levelIntro($level);
    def url as string init SITE_URL + "levels/" + $level + "/";
    def title as string init $name + " talks - " + SITE_TITLE;
    return page($title, $description, keywordsOf($mine), $url, "../../", $body) + pageEnd(false);
}

/**
 * llms.txt (llmstxt.org): the site and every talk as Markdown links, for
 * language-model crawlers that read text rather than run the page's script.
 * @param {list of Talk} talks all sorted talks
 * @return {string} llms.txt
 */
export func llmsTxt(talks as list of Talk) {
    def out as string init "# " + SITE_TITLE + "\n\n> " + SITE_DESCRIPTION + "\n\n";
    $out = $out +
        "Each talk is a slideshow (HTML, with speaker notes) and a PDF, licensed CC BY 4.0 ";
    $out = $out + "by its author. The whole catalogue as JSON: " + SITE_URL + "talks.json\n";
    for (def level in levelsOf($talks)) {
        $out = $out + "\n## " + levelName($level) + " talks\n\n";
        for (def t in byLevel($talks, $level)) {
            def m as meta.Meta init $t.meta;
            $out = $out + "- [" + $m.title + "](" + SITE_URL + talkPath($t) + "): " +
                $m.description + " Tags: " + strings.join($m.tags, ", ") + ". PDF: " + SITE_URL +
                pdfPath($t) + "\n";
        }
    }
    $out = $out + "\n## Optional\n\n";
    $out = $out + "- [Contributing a talk](" + REPO_URL + "/blob/main/CONTRIBUTING.md)\n";
    return $out + "- [The Jennifer documentation](https://docs.jennifer-lang.dev/)\n";
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
    $body = $body + cards($mine, "../", true, "") + jsonLd($mine);
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
    def body as string init "<h1>Talks tagged " + esc($tag) + "</h1>\n" +
        "<nav class=\"pagenav\" aria-label=\"Talks\"><p class=\"count\">" + talksCount(len($mine)) +
        "</p><a href=\"../../\">All talks</a></nav>\n" + cards($mine, "../../", true, $tag) +
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
        def month as string init modifiedOf($t);
        def alt as string init alternatesXml($t);
        for (def v in meta.versionsOf($t.meta)) {
            def url as string init esc(SITE_URL + versionPath($t, $v));
            $out = $out + "<url><loc>" + $url + "</loc><lastmod>" + esc($month) + "</lastmod>";
            $out = $out + $alt + "</url>\n" + loc(SITE_URL + versionPdf($t, $v), $month);
        }
    }
    for (def level in levelsOf($talks)) {
        $out = $out + loc(SITE_URL + "levels/" + $level + "/", "");
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
        $doc = json.set($doc, "/modified", modifiedOf($t));
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

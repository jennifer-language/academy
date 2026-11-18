# Contributing a talk

The Jennifer Academy publishes talks that teach the Jennifer programming
language, written by the people who use it, at
<https://academy.jennifer-lang.dev/>. A talk is a Markdown file that
[Cantrip](https://github.com/jennifer-language/cantrip) turns into a slideshow
for the browser and a PDF. This page says how to add one and which rules it
must meet. Every rule is checked by `tools/check.j`, locally and in CI.

## In short

1. Fork this repository and create `talks/<your-github-user>/<topic>/`.
2. Write `talk.md` (the slides) and `academy.toml` (the catalogue entry) there,
   with your images beside them.
3. Run the checks (see [Checking locally](#checking-locally)).
4. Open a pull request, fill in what it adds, and tick the
   [contributor declaration](#the-declaration).

## Where a talk lives

```text
talks/<github-user>/<topic>/talk.md        the slides (or talk.<lang>.md per language)
talks/<github-user>/<topic>/academy.toml   the catalogue entry
talks/<github-user>/<topic>/*.png|jpg|gif  its images, beside talk.md
```

The talk is published at `https://academy.jennifer-lang.dev/<github-user>/<topic>/`,
its PDF at `.../<topic>/<topic>.pdf`. A talk in several languages is described
in [Talks in several languages](#talks-in-several-languages).

- **The namespace is your personal GitHub account**, written in lower case.
  Each talk has one responsible person, the account under which it is
  published, so organisations are not accepted as namespaces.
- **The topic** is a slug: lowercase `a-z`, `0-9` and single inner hyphens
  (`intro-to-tasks`). It is the last part of the URL, so keep it short.
- **One talk per directory**, holding its talk file(s), `academy.toml` and
  images (`.png`, `.jpg`, `.jpeg`, `.gif`) only: no subdirectories, no
  symbolic links, no other files.
- **Images are read only from the talk's own directory.** Cantrip refuses an
  image outside it, and the checker does too. If several of your talks show the
  same picture, give each talk its own copy.

### Namespaces in pull requests

A pull request may add or change talks only under `talks/<its-author>/`. CI
compares every changed path with the pull request's author, and asks the
GitHub API that each namespace touched is a personal account (`type` is
`User`), not an organisation.

Maintainers (the repository's owner, members and collaborators) may change any
talk, by a direct push or in their own pull request; the namespace check
exempts them. That is how a maintainer fixes a typo or a broken link in
someone else's talk. Contributors who want to improve another person's talk
open an issue, or ask that person.

## academy.toml

The catalogue entry. The front page, the author, level and tag pages, the sitemap,
`talks.json` and the talk's HTML and PDF metadata are built from it. The schema
is strict: an unknown key, a wrong type or a bad value fails the check.

```toml
title       = "Tasks and channels in practice"
description = "How to split work across tasks with spawn, collect results with task.wait, and stream values through channels, with the mistakes beginners make most."
author      = "octocat"
name        = "Mona Example"
license     = "CC-BY-4.0"
lang        = "en"
jennifer    = "0.26.0"
date        = "2026-11"
updated     = "2026-12"
level       = "intermediate"
tags        = ["concurrency", "tasks", "channels"]
```

| Key | Required | Value |
| --- | --- | --- |
| `title` | yes | The talk's title, 1 to 80 characters of plain text. |
| `description` | yes | What a search engine shows: 50 to 300 characters of plain text, no links. |
| `author` | yes | Your GitHub login; must equal the namespace directory. |
| `name` | no | Your display name, up to 80 characters. Shown as "Mona Example (@octocat)". |
| `license` | yes | `"CC-BY-4.0"`, the only licence accepted (see [Licences](#licences)). |
| `lang` | yes | The talk's (primary) language, an ISO 639-1 code: `"en"`, `"de"`, `"fr"`. |
| `jennifer` | yes | The release the talk is based on, `X.Y.Z`. The slides must say it too (see rule 2). |
| `date` | yes | When the talk was first published, `YYYY-MM`. |
| `updated` | no | When it last changed substantially, `YYYY-MM`, not before `date`. Shown on the card, and "Newest first" sorts by it. Leave it for small fixes; CI reminds you when the slides changed by 20 lines or more. Search engines get the day of the last commit either way. |
| `level` | yes | `"beginner"`, `"intermediate"` or `"advanced"`. |
| `tags` | yes | 1 to 8 tags, each lowercase `a-z`, `0-9` and single hyphens, at most 24 characters. Shared by every language. Reuse a tag other talks already have where one fits (`errors`, not `error-handling`): the front page's topic filter lists only tags two or more talks share. The level is its own field, so no `beginner` tag. |
| `[translations.<lang>]` | no | One table per further language: `title` and `description` (same limits as above), optional `keywords` (plain text, at most 200 characters). See below. |

Write these values once, here. `tools/build.sh` copies `title`,
`description`, `keywords` (from `tags`), `lang`, `author` and `date` into the
front matter of a temporary copy of `talk.md` before Cantrip runs, so the
slideshow and the PDF carry them. `talk.md` must therefore not set them itself.

## Talks in several languages

A talk may come in several languages. It then has one file per language,
`talk.<lang>.md`, instead of `talk.md`; `<lang>` is an ISO 639-1 code in lower
case (`talk.de.md`, not `talk.DE.md` or `talk.deu.md`). The two forms are not
mixed in one directory.

```text
talks/octocat/tasks/talk.en.md       the primary language, as academy.toml's lang
talks/octocat/tasks/talk.de.md       a translation
talks/octocat/tasks/academy.toml
```

```toml
title       = "Tasks and channels in practice"
description = "How to split work across tasks with spawn, collect results with task.wait, and stream values through channels."
lang        = "en"
# ... the other keys as above ...

[translations.de]
title       = "Tasks und Channels in der Praxis"
description = "Wie man Arbeit mit spawn auf Tasks verteilt, Ergebnisse mit task.wait einsammelt und Werte durch Channels schickt."
keywords    = "jennifer, nebenläufigkeit, tasks, channels"
```

- `lang` names the primary language, which must have its `talk.<lang>.md`.
- Every other `talk.<lang>.md` needs a `[translations.<lang>]` table, and every
  table needs its file.
- Tags, level, date and author are shared. A version may be shorter than the
  primary one, but has at least one slide, and every rule applies to every
  version: notes, links, code, the author slide (an Impressum for a German
  version), a build without warnings.
- The primary language keeps the talk's address,
  `/<github-user>/<topic>/`; each translation is published at
  `/<github-user>/<topic>/<lang>/`, with its PDF as `index.pdf` beside it. Each
  version names the others for search engines (`hreflang`).
- **Character set:** the PDF is drawn in the standard PDF fonts, which cover
  Western European text (Windows-1252). German, French, Spanish, Italian,
  Dutch, Portuguese or the Nordic languages work; Greek, Cyrillic, CJK and
  other scripts cannot be shown in the PDF, so talks in them are refused until
  Cantrip embeds a Unicode font.
- Content in a language other than English needs a translation review by a
  maintainer before it is merged; see
  [Review of talks in other languages](#review-of-talks-in-other-languages).

## talk.md

A Cantrip deck: front matter, then slides separated by a line of `---`. The
format, the themes and the transitions are described in
[Cantrip's documentation](https://github.com/jennifer-language/cantrip/blob/main/docs/format.md).

```markdown
---
theme: carbon
ratio: 16:9
transition: slide
---

# Tasks and channels in practice

Based on **Jennifer 0.26.0**, by [@octocat](https://github.com/octocat).

<!-- notes: what this talk covers, and for whom -->

---

## spawn returns a task

...
```

The front matter holds how the talk is presented, nothing else: `theme`
(required), `mode`, `ratio` and `transition` (optional). `mode: light` or
`mode: dark` picks the palette the talk opens in (light by default); a viewer
switches it with <kbd>m</kbd>.

Every academy talk opens with its speaker notes shown below the slide (on a
large screen; <kbd>s</kbd> hides them, `?notes=0` in the URL starts without
them). The build sets Cantrip's `notes: open` for that, so a talk does not set
`notes` itself, and since the notes are part of what readers see, write them
for readers as well as for yourself.

## Who you are

Every talk names its author, in the talk itself, in one of two ways:

- **`@<your-github-user>` on the title slide**, as text or as a link to
  `https://github.com/<your-github-user>`. A link to another account does not
  count; or
- **a final Imprint slide**: the last slide has the heading `## Imprint`
  (`## Impressum` in a talk with `lang = "de"`) and at least one line of text
  that is not just a heading or a link.

You are encouraged to add an imprint that meets the law of your own country.
The academy cannot advise you on that. As examples of what is often expected:
in Austria, name and place of residence (city) for a small, non-commercial
publication; in Germany, name and a postal address where the publication is
commercial or journalistic-editorial; in many other countries, nothing is
required.

```markdown
---

## Imprint

Mona Example, Vienna, Austria

[@octocat](https://github.com/octocat) on GitHub

<!-- notes: who is responsible for this talk -->
```

Personal data on your imprint slide is your own choice and is published with
the talk. It falls under the rule on personal data of others only if it is
someone else's.

## The rules

`tools/check.j` checks every rule and prints `file:line: rule: message` for
each problem.

| # | Rule | How it is checked |
| --- | --- | --- |
| 1 | **No external links or images.** Links point only into the Jennifer project (the allowlist below). Images are local files beside `talk.md`. | Every Markdown link and image target, reference definition, autolink and bare URL in the text, outside fenced code and code spans, is matched against the allowlist. |
| 2 | **Front matter and catalogue entry.** `talk.md` sets `theme` and at most `mode`, `ratio` and `transition`; `academy.toml` follows the schema above. The slides state the Jennifer version from `academy.toml` ("Based on Jennifer 0.26.0"). | Front-matter keys are compared with the allowed list; `academy.toml` is parsed with Jennifer's `toml` module and every key validated; the text is searched for "Jennifer X.Y.Z". |
| 3 | **Every slide has speaker notes of at least 40 words**, a `<!-- notes: ... -->` comment. Write what you would say: the explanation, the example you would give, the question you would ask the room. A reader of the published talk has only the slides and the notes. A closing imprint slide needs notes, but they may be short. | The slides are split the way Cantrip splits them; each needs a notes comment outside code, and its words are counted. |
| 4 | **The talk builds with Cantrip without a warning.** A warning means a slide overflowed its page. | The talk is built with Cantrip; any `cantrip: warning:` line fails. |
| 5 | **Every `jennifer` code block parses**, unless it is marked as an excerpt. | Each block is written to a file and run through `jennifer ast` (parse and name resolution); an excerpt through `jennifer tokens` (it must lex). |
| 6 | **UTF-8 without a byte-order mark, and no em-dashes (U+2014) or en-dashes (U+2013).** | The bytes of `talk.md` and `academy.toml` are checked; the dash rule also covers the repository's own Markdown, tools and workflows. |
| 7 | **One talk per directory**, with valid names (see [Where a talk lives](#where-a-talk-lives)): `talk.md` or `talk.<lang>.md` files, never both. | The tree under `talks/` is walked. |
| 8 | **The talk names its author** (see [Who you are](#who-you-are)). | The first slide is searched for `@<namespace>` or a link to its GitHub profile; the last for an Imprint. |
| 9 | **Every character can be shown in the PDF.** Cantrip's PDF fonts cover Windows-1252 only; anything else (an arrow `→`, an emoji, Greek or Cyrillic letters) would print as `?`. This applies to text, notes and code alike: write `->` or "gives" instead of an arrow. `ä ö ü ß é ² €` and typographic quotes are fine. | Each line of every talk file is matched against the Windows-1252 set; each other character is reported with its code point. |
| 10 | **Languages match** (see [Talks in several languages](#talks-in-several-languages)). | File names are checked against ISO 639-1, and the files against academy.toml's `lang` and `[translations.<lang>]` tables. |
| 11 | **At most 20 slides.** A longer subject is two talks, each of which can be given on its own. | The slides are counted the way Cantrip splits them. |

### The link allowlist

A link in a talk may point only to:

- `jennifer-lang.dev` and every subdomain (`www.`, `docs.`, `registry.`,
  `jvc.`, `grimoire.`, `academy.`, `git.`, ...);
- `github.com/jennifer-language/...`, `github.com/deckyard/...` and
  `github.com/mplx/...`, the project's accounts;
- `github.com/topics/grimoire-plugin`;
- `github.com/<your-github-user>/...`: your own profile and repositories, in
  your own talks.

Only `http` and `https` URLs qualify; `mailto:`, a port, or user information
in the URL fail. Everything else fails, including other GitHub accounts and
`*.github.io`. The list is defined once, at the top of `tools/rules.j`. Links
in fenced code blocks and code spans are not links and are not checked.

### Code blocks and excerpts

A block fenced as ```` ```jennifer ```` must be a complete program that the
interpreter parses: `jennifer ast` reads it, so an undefined variable or a
missing `use` fails as well as a syntax error.

A block that is deliberately a fragment (a function body without its
definitions, a line with `...` in it, code that shows an error on purpose) is
marked as an **excerpt** with a second word in its fence:

````markdown
```jennifer excerpt
func total(xs as list of int) { ... }
```
````

The slide shows it exactly like any other Jennifer block (the fence's first
word is the language). An excerpt is only checked to lex, so an unterminated
string still fails. Mark only what really is a fragment.

## Checking locally

You need the Jennifer interpreter (0.26.0 or a newer build) and a checkout of
Cantrip:

```sh
git clone https://github.com/jennifer-language/cantrip.git ../cantrip
export CANTRIP=../cantrip/bin/cantrip
jennifer run tools/check.j                        # every rule, every talk
jennifer run tools/check.j talks/octocat/my-talk  # one talk
jennifer run tools/check.j --fast                 # skip parsing code and building
tools/build.sh                                    # the whole site, into site/
```

Open `site/<your-github-user>/<topic>/index.html` to see your slides; press
<kbd>?</kbd> for the keys and <kbd>s</kbd> for your notes.

## The declaration

Every pull request that adds or changes a talk carries the contributor
declaration from `.github/pull_request_template.md` in its description, with
all five items ticked (`- [x]`). CI checks that each item is present, unchanged
in substance and ticked, and fails otherwise. If it fails, edit the pull
request's description; the check runs again. Maintainers' own pull requests
are exempt.

## Content policy

Never accepted:

- extremist symbols and propaganda;
- hate, harassment and discrimination;
- personal data of others without their consent;
- material whose rights the author does not hold;
- malware, or code that harms readers who run it;
- advertising, and links outside the project (the link rule above).

Each talk is published under its author's personal account, and its author
alone is responsible for it.

## Review

Nothing is published without a maintainer's review and merge. The maintainers
may decline, change or remove any talk at any time, without giving reasons.

## Review of talks in other languages

A pull request that adds or changes content in a language other than English
needs a translation review: a `talk.md` whose `lang` is not `en`, any
`talk.<lang>.md` other than `talk.en.md`, or an academy.toml holding a
non-English title or description. CI's `translation-review` check passes only
when a maintainer (the repository's owner, a member or a collaborator) other
than the author has approved the pull request's **current** commit (a new push
needs a new review) with this declaration in the review, every item ticked:

```markdown
## Reviewer declaration

- [ ] I translated the complete text, speaker notes and code comments of every non-English talk file in this pull request into English, myself or with a translation tool, and read the translation in full.
- [ ] I looked at every image in it.
- [ ] To the best of my knowledge and judgement, the content is lawful and follows the academy's content policy.
```

Reviewers paste it into their approving review and tick the boxes. A later
review by the same maintainer that requests changes, or a dismissed review,
no longer counts.

A pull request by a maintainer is exempt, because GitHub does not let anyone
approve their own pull request; a maintainer takes the same care with their own
non-English content.

## Reporting content (notice and takedown)

To report a talk that breaks the law or this policy, write to
<mplx@jennifer-lang.dev> with the talk's URL and what is wrong with it. For a
case that is not sensitive, a GitHub issue in this repository works too.
Reported talks are taken offline promptly while the report is checked.

## Licences

- **Talks** (everything under `talks/`) are licensed under the
  [Creative Commons Attribution 4.0 International licence](LICENSE)
  (CC BY 4.0), by their authors. Code samples in a talk are also available
  under the repository's tool licence, LGPL-3.0-only.
- **Tools** (everything under `tools/` and `.github/`) are licensed under the
  [GNU Lesser General Public License v3.0 only](LICENSE-tools)
  (LGPL-3.0-only); each file carries an SPDX header.

## Disclaimer

**Disclaimer.** The talks are provided as is, without warranty of any kind, express or implied, including accuracy, completeness, currency or fitness for a particular purpose. Each talk is the work and the responsibility of its author. Use the information and code in them at your own risk. To the extent permitted by law, the maintainers of the Jennifer project are not liable for any damage arising from the use of this site or its talks. Nothing here is legal, financial or professional advice.

Each talk is also covered by the disclaimer of warranties in Section 5 of
CC BY 4.0, and its code by that of the LGPL.

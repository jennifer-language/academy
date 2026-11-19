# Jennifer Academy

Talks that teach the [Jennifer programming language](https://jennifer-lang.dev/),
written by the people who use it, published at
**<https://academy.jennifer-lang.dev/>**.

Each talk is a Markdown file built with
[Cantrip](https://github.com/jennifer-language/cantrip) into a slideshow for
the browser and a PDF, and lives under its author's GitHub account:

```text
talks/<github-user>/<topic>/talk.md        the slides (talk.<lang>.md per language
                                           for a talk in several languages)
talks/<github-user>/<topic>/academy.toml   the catalogue entry
talks/<github-user>/<topic>/*.png          its images
talks/<github-user>/<topic>/code/          the programs behind the slides (optional)
```

A translation is published below its talk, at `/<github-user>/<topic>/<lang>/`.

The talk `talks/mplx/classroom/` is at
<https://academy.jennifer-lang.dev/talks/mplx/classroom/>.

**Contributing a talk:** see [CONTRIBUTING.md](CONTRIBUTING.md), with the
[content policy](CONTRIBUTING.md#content-policy) and the
[contributor declaration](CONTRIBUTING.md#the-declaration) every pull request
carries. The talks are provided as is: see the
[disclaimer](CONTRIBUTING.md#disclaimer).

## The tools

All written in Jennifer, under `tools/`:

| File | What it does |
| --- | --- |
| `check.j` | Checks every talk against the rules in CONTRIBUTING.md, its `code/` folder too, linting each program (`--fast` skips parsing and linting code, and building). |
| `build.sh` | Builds the site into `site/`: every talk under `talks/` (HTML, PDF and an A4 handout, and its `code/` folder with a listing, a page per text file and a zip), redirects from the addresses talks had before they moved there, the front page, author, level and tag pages, the legal page (from `legal.md`), `sitemap.xml`, `robots.txt`, `talks.json`, `llms.txt`, `CNAME`. |
| `rules.j`, `meta.j` | The rules and the `academy.toml` schema, as a module (`rules_test.j` holds the negative cases). |
| `site.j`, `gallery.j` | The academy's own pages (`site_test.j` tests order and escaping). |
| `prepare.j` | Injects a talk's `academy.toml` fields into a copy of `talk.md` for cantrip. |
| `declaration.j`, `check-declaration.j` | The pull-request declaration check (`declaration_test.j`). |
| `review.j`, `check-review.j` | The translation-review check for non-English content (`review_test.j`). |
| `namespaces.sh` | The pull-request namespace checks CI runs on GitHub. |
| `update-hint.sh` | The pull-request reminder to set `updated` after a large change to a talk. |
| `install-jennifer.sh` | Installs the interpreter CI pins (a release or a commit). |

Locally, with an interpreter and a Cantrip checkout:

```sh
export CANTRIP=../cantrip/bin/cantrip        # in the workspace: ../apps/cantrip/bin/cantrip
jennifer run tools/check.j
for t in tools/*_test.j; do jennifer test "$t"; done
tools/build.sh                               # then open site/index.html
```

## talks.json

`https://academy.jennifer-lang.dev/talks.json` is the merged catalogue, for
other sites and tools:

```json
{
  "version": 1,
  "site": "https://academy.jennifer-lang.dev/",
  "talks": [
    {
      "author": "mplx",
      "name": "",
      "topic": "classroom",
      "title": "Jennifer for the classroom",
      "description": "...",
      "license": "CC-BY-4.0",
      "lang": "en",
      "jennifer": "0.26.0",
      "date": "2026-11",
      "updated": "",
      "modified": "2026-11-18",
      "level": "beginner",
      "tags": ["teaching", "education"],
      "url": "https://academy.jennifer-lang.dev/talks/mplx/classroom/",
      "pdf": "https://academy.jennifer-lang.dev/talks/mplx/classroom/classroom.pdf",
      "handout": "https://academy.jennifer-lang.dev/talks/mplx/classroom/classroom-handout.pdf",
      "versions": [
        {
          "lang": "en",
          "primary": true,
          "title": "Jennifer for the classroom",
          "description": "...",
          "url": "https://academy.jennifer-lang.dev/talks/mplx/classroom/",
          "pdf": "https://academy.jennifer-lang.dev/talks/mplx/classroom/classroom.pdf",
          "handout": "https://academy.jennifer-lang.dev/talks/mplx/classroom/classroom-handout.pdf"
        }
      ]
    }
  ]
}
```

The talks are sorted newest first (`updated`, else `date`), then by title.
`name` and `updated` are `""` when the talk does not set them. A talk with a
`code/` folder also has `code` (the URL of its listing,
`.../<topic>/code/`) and `codeZip` (`.../<topic>/<topic>-code.zip`); a talk
without one has neither field. `modified` is
the day the talk's directory last changed in git (any change, a typo fix too),
or the `updated` / `date` month when the build has no git history; `updated` is
the author's own "this changed substantially", the date readers see. The top-level
`title`, `description`, `lang`, `url`, `pdf` and `handout` are the primary
language's; `versions` lists every language, the primary first, a translation
with its own `url` (`.../<lang>/`), `pdf` (`.../<lang>/index.pdf`) and `handout`
(`.../<lang>/handout.pdf`). `version` goes
up when a field changes meaning or goes away; new fields may be added.

## CI and publishing

`.github/workflows/ci.yml` runs on every push and pull request:

- **site** (GitHub and Forgejo): formats and lints the tools, runs their tests,
  runs `tools/check.j`, builds the site and checks the PDFs with `qpdf`. The
  interpreter is pinned by `JENNIFER_REF` and Cantrip by `CANTRIP_REF`, each a
  release tag.
- **accounts** (GitHub only): every namespace a change touches must be a
  personal GitHub account, asked through the GitHub API.
- **ownership** and **declaration** (GitHub pull requests only): changed talks
  must be in the author's namespace, and the description must carry the ticked
  declaration. Maintainers are exempt.
- **translation-review** (`.github/workflows/review.yml`, GitHub pull
  requests and reviews only): a pull request changing non-English talk content
  needs a maintainer's approval of its head commit with the ticked reviewer
  declaration. A submitted, edited or dismissed review re-runs it. It has a
  workflow of its own so that a review re-runs only this check: in `ci.yml` a
  review would report the other jobs as skipped, and a required check counts a
  skipped run as passed. Maintainers' own pull requests are exempt.
- On GitHub, `check.j` annotates each talk problem on its file and line and
  lists them, grouped by talk, in the job summary.
- **update-hint** (GitHub pull requests only): when a talk's slides change by
  20 lines or more and its `updated` stays as it was, a notice (never a
  failure) suggests setting it; `tools/update-hint.sh`.
- **deploy** (GitHub, pushes to `main`): publishes `site/` to GitHub Pages.

### One-time setup

In the GitHub repository's settings:

1. **Pages**: Source "GitHub Actions".
2. **Pages**: Custom domain `academy.jennifer-lang.dev` (the build also writes
   `site/CNAME`).
3. **Pages**: tick "Enforce HTTPS" once the certificate has been issued.
4. **Environments**: `github-pages` allows deployments from `main`.
5. **Ruleset** "main" on `main` (set up), so the checks block merges:
   require a pull request before merging, and require the status checks
   "Check and build the talks" (site), "Namespaces are GitHub users"
   (accounts), "Talks stay in the author's namespace" (ownership),
   "Contributor declaration" (declaration) and "Translation review"
   (translation-review). Without it they only report.

DNS (already set up): a `CNAME` record for `academy.jennifer-lang.dev`
pointing to `jennifer-language.github.io`.

The site's `/legal/` page (responsibility per author, how to report a talk,
the disclaimer) is built from `legal.md`. The site has no imprint; if one is
ever wanted, it goes into that file.

## Licences

- Talks (`talks/`): [CC BY 4.0](LICENSE), by their authors.
- Sample code (each talk's `code/` folder, and the code on its slides):
  [MIT-0](LICENSE-code), so it can be copied into any project without
  attribution. Every `code/` folder carries its own `LICENSE` with the MIT-0
  text, and CI checks it on every push and pull request.
- Tools (`tools/`, `.github/`): [LGPL-3.0-only](LICENSE-tools), with SPDX
  headers.

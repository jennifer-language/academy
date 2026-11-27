---
theme: meridian
ratio: 16:9
transition: slide
---

# Sharing your code as a deck

![Jennifer](jennifer-logo.png)

Tiers, publishing, promotion, and how people find what you wrote.

November 2026, by [@mplx](https://github.com/mplx).\
Based on **Jennifer 0.28.0**

<!-- notes:
This talk is for people who have written a few Jennifer programs and now have
code worth sharing: a parser, a client for some service, a set of helpers you
copy from project to project. We look at what a deck is, which tiers of decks
exist and what each one promises, how to start and publish your own, how a
deck moves between tiers, and what makes it easy to find. The companion talk
"Writing and publishing your first deck" goes deeper into the build itself.
-->

---

## What a deck is

- A **library of Jennifer modules** in its own git repository
- A **scoped name**: `@deckyard/money`, `@yourname/beaufort`
- `jvc` copies its `src/` into your project's `vendor/scope/deck/`
- You import it with a trailing slash: `import "@scope/name/";`

| Name | What it is | Comes from |
| --- | --- | --- |
| `http` (bare) | a bundled module | the interpreter |
| `@scope/deck` | a deck | `jvc install`, into `vendor/` |

<!-- notes:
Jennifer has two kinds of reusable code. A bare name such as http or csv is a
module that ships with the interpreter. Everything else is a deck, and a deck
always has a scope in front of its name. There is nothing to compile: a deck
is source, and what you receive is exactly the src directory of the version
you pinned. Its tests, docs and examples stay in its repository.
-->

---

## Using a deck

```sh
jvc add @deckyard/money     # writes the [decks] line in deck.toml
jvc install                 # vendor/deckyard/money/ + camcorder.lock
```

```jennifer
use io;
import "@deckyard/money/";

def price as money.Money init money.parse("19.90", "EUR");
io.printf("%s\n", money.format($price));
```

<!-- notes:
jvc add records the requirement in your deck.toml, and jvc install resolves
it against the registry, copies the deck's src into vendor and pins the exact
commit in camcorder.lock. Commit the lock file, ignore vendor in git. The
trailing slash imports the deck's entry module and binds its name, here
money, as the namespace. A sibling checkout on your disk is not found: the
at sign resolves only under vendor.
-->

---

## Four tiers, one reserved name

| Tier | Scope | Holds | Gets there by |
| --- | --- | --- | --- |
| 1 | core, no scope | interpreter, built-in libraries, bundled modules | the core team |
| 2 | `@deckyard` | major community decks | requirements, users, a vote |
| 3 | `@skiffyard` | smaller community decks | requirements, one review |
| 4 | `@<user>` | anyone's decks | `jvc publish` |
| - | `@jennifer` | reserved, no decks | - |

<!-- notes:
A scope tells you who looks after a deck and how much weight it carries. The
tiers come from three places that say the same thing: the scopes section of
Jennifer's docs/decks.md, and the CONTRIBUTING files of Deckyard and
Skiffyard. Tiers two and three are community organisations with their own
maintainers; neither is part of the Jennifer project. Tier four is where every
deck starts, including the ones that later move up.
-->

---

## Tier 1: core, and the reserved @jennifer

- The **jennifer-language** organisation holds only what the core team
  maintains: the interpreter, its libraries, the bundled modules
- **No decks live there.** In 0.28.0 every `@jennifer` deck moved to
  `@deckyard`; nine bundled modules became decks the same way
- `@jennifer` stays **reserved**: nobody can claim it, and its old names
  answer with a moved record

```text
@jennifer/slack moved to @deckyard/slack; change the [decks] entry
and the imports (`@deckyard/slack/`)
```

<!-- notes:
Core is what you get by installing the interpreter; you depend on it through
the engine floor in your manifest, not through jvc. Until 0.28.0 the project
also published decks of its own under @jennifer. They all moved to Deckyard,
together with nine bundled modules such as slack, telegram and mikrotik. The
message on the slide is what jvc prints for an old name. That move is the
real example of what a tier change costs, which we come back to later.
-->

---

## Tiers 2 and 3: the same technical bar

Deckyard and Skiffyard accept a deck only while it has:

- **a maintainer** who uses what the deck wraps and keeps CI green on the
  current Jennifer release
- **tests that run in CI without accounts or network**, every export covered
- **documentation checked against the code**: a guide per area, every export
  in the cheatsheet, examples CI runs or parses
- **strict input handling**: one typed error struct, size caps, deadlines,
  no credential in a message or URL
- **the shared CI layer**, unmodified

<!-- notes:
This list is word for word the same in both organisations' CONTRIBUTING
files. What separates the two tiers is not quality but audience: a Deckyard
deck has a noticeable user base, a Skiffyard deck may serve a small niche.
A client is tested against a local fake that checks the requests it sends,
not only the answers it parses. And note "stays only while": a deck that stops
meeting the bar is not kept for its name.
-->

---

## Deckyard and Skiffyard

| | Deckyard | Skiffyard |
| --- | --- | --- |
| Audience | broad | narrower |
| Joins by | user base + vote | one maintainer's review |
| Maintainers | two per deck is the goal | one is enough |
| Decks | 58 | none yet |
| Organisation | [github.com/deckyard](https://github.com/deckyard) | [github.com/skiffyard](https://github.com/skiffyard) |

<!-- notes:
Deckyard holds the major community decks: clients for container hosts and
code forges, file formats such as EPUB and GPX, the decks that left core. Skiffyard
is the smaller yard beside it: a skiff is a small, light boat, and smaller
decks are looked after there. Skiffyard is being set up now: its rules are written, its deck
list is still empty. Both organisations name each deck's maintainers in
CODEOWNERS and create its repository as deck-<name> from the template.
-->

---

## Tier 4: your own scope

- Your **GitHub™ username** is your scope: `jvc claim yourname`
- Or an **organisation** you belong to: the scope then belongs to it
- No review, no vote: publish when the gate is green
- Every deck starts here, the ones that later move up included

> Most decks never need to leave tier 4. That is fine.

<!-- notes:
The registry derives scopes from GitHub: you may claim the scope that matches
your login and one for each organisation your login carries. An organisation
that restricts third-party access has to approve the registry's application
before its scope can be claimed; then you log in again. Both CONTRIBUTING files
say it plainly: most decks do not need Deckyard or Skiffyard, and publishing
under your own name is the right path for them.
-->

---

## Start from the template

```sh
git clone https://github.com/jennifer-language/deck-template \
    deck-beaufort
cd deck-beaufort && rm -rf .git && git init
tools/init-deck.sh yourname beaufort "Wind speed to Beaufort force"
rm TEMPLATE.md tools/init-deck.sh tools/sync-deck.sh
tools/check-all.sh
```

A working deck from the first minute: one export, one test, one example,
docs, green CI.

<!-- notes:
deck-template is a minimal deck that already passes its own gate.
init-deck.sh renames the module, rewrites the deck name and the repository
and Pages addresses in every file, and writes the lock of the shared files.
The three template-only files must go: the identity check fails while any
trace of the placeholder name is left. The template is optional for a tier 4
deck, but it gives you the checks Deckyard and Skiffyard run.
-->

---

## What is in it

| Path | What it is |
| --- | --- |
| `deck.toml` | the manifest: name, version, licence, floor |
| `src/beaufort.j` | the entry module consumers import |
| `src/beaufort_test.j` | its test overlay, one beside every module |
| `docs/` | the book: `SUMMARY.md`, `cheatsheet.md`, `design.md` |
| `examples/` | runnable programs; CI runs or parses them |
| `tools/`, `.github/` | the shared CI layer; `tools/check-all.sh` |
| `AGENTS.md` | optional notes for coding agents, shared too |

<!-- notes:
Only src ships; everything else stays in your repository. The shared CI layer
is listed in tools/shared-files and pinned by tools/shared.lock: the same
workflows and checks in every deck, fixed once in the template and synced
out. Never edit a shared file in your deck; a check that only your deck needs
goes in tools/check-extra.sh, and how your examples run goes in
tools/check-examples.sh.
-->

---

## deck.toml

```toml
[package]
name = "@yourname/beaufort"
version = "0.1.0"
description = "Wind speed to Beaufort force"
license = "LGPL-3.0-only"
capabilities = []
keywords = ["weather", "wind", "beaufort"]

[engines]
jennifer = ">=0.28.0"
```

<!-- notes:
The manifest is the single source of truth. The name is scoped and lower case;
the deck half becomes a namespace, so it is letters and digits only.
Capabilities are net, exec or sql, and empty means pure. The engine floor
takes ">=X.Y.Z" or ">=X.Y.Z <A.B.C". Description and keywords look like
decoration, but they decide whether anyone finds your deck, as we will see.
init-deck.sh also fills in [package.urls]: the deck URL, the homepage, and
manual, the address of your documentation site.
-->

---

## The gate: tools/check-all.sh

| Step | Checks |
| --- | --- |
| shared | no shared file was edited |
| format, lint | `jennifer fmt -l`, `jennifer lint` |
| headers | SPDX header and floor in every source file |
| overlays, coverage | a test overlay per module, every export called |
| src, docs | only Jennifer source in `src/`; the cheatsheet matches the code |
| identity | no template name left |
| suites, examples | the tests pass, the examples run |

<!-- notes:
CI runs exactly this script, so a green run on your machine means a green run
on GitHub. Every step runs even after one fails, so one pass lists everything
to fix. The two checks beginners meet first are coverage, which wants every
exported function called from a test at least once, and docs, which compares
every signature in the cheatsheet with the code.
-->

---

## Publishing to the registry

```sh
jvc login                  # approve a code in your browser
jvc claim yourname         # once: your scope
# bump the version in deck.toml and commit, then:
git tag 0.1.0
git push origin 0.1.0
jvc publish
```

- The tag **is** the version, plain `N.N.N`: `0.1.0`, never `v0.1.0`
- The template's `release.yml` refuses a tag that differs from the manifest

<!-- notes:
jvc login uses GitHub's device flow: it prints a code, you approve it in a
browser where you are signed in. The registry itself reads a tag with or
without a v, but the shared release workflow builds only plain tags, and the
community organisations refuse v tags outright. So bump the manifest first,
then tag that commit. If origin is not your GitHub repository, add
--remote github.
-->

---

## What jvc publish checks

| Where | Check |
| --- | --- |
| your machine | valid manifest and engine range |
| | the gate: lint, every overlay from a copy of `src/`, docblocks |
| | a tag on `HEAD` that matches the version |
| the registry | reads `deck.toml` **at the tag**, through the forge |
| | the scope in `name` is yours, and you can push to the repository |
| | the version is new (`409` otherwise); `src/<deck>.j` exists |

**Nothing is uploaded.** The tag resolves to a commit, and the commit is the pin.

<!-- notes:
jvc runs its own quality gate first: lint, every module's test overlay run
from a copy of src the way a consumer gets it, and the docblocks. Then it
sends the registry only a repository and a tag. The registry reads the
manifest at that commit itself, so you cannot publish into a scope your
manifest does not name, or a repository you cannot push to.
-->

---

## After the release

- A published version is **immutable**: fix forward with a new version
- **Yank** a bad one: `jvc yank @yourname/beaufort 0.1.0`
  (`jvc unyank` takes it back)
- A yanked version is never chosen again, but a lock file that pins it
  still installs
- From CI: **trusted publishing**, with no stored secret, or `$JVC_TOKEN`
- Users can run your tests: `jvc install --run-untrusted-tests`

<!-- notes:
Deleting a version would break every build that pins it, so the registry
offers yank instead. Users leave a yanked version with jvc update. For
releases from CI, trusted publishing is the best choice: the runner's identity
token is checked against a publisher registered once for your deck. And a
user who runs your overlays on their interpreter catches a deck that only
works on yours.
-->

---

## Moving up

| Move | Needs | Decided by |
| --- | --- | --- |
| `@you` to `@skiffyard` | the requirements | one maintainer of Skiffyard or Deckyard, or an owner |
| `@you` or `@skiffyard` to `@deckyard` | the requirements + a noticeable user base, recently | a majority of the votes cast by the Deckyard maintainers |

Open **Propose a new deck** in the organisation's `.github` repository:
what it does, who maintains it, licence, outside dependencies, where it
stands (and for Deckyard: who uses it).

<!-- notes:
"Recently" matters: people install it, depend on it or report issues against
it now, not only at its first release. A Skiffyard proposal needs no user base
and no vote; the reviewer answers in the issue, accepted or what is still
missing. An accepted deck moves to a repository named deck-<name> in the
organisation, created from the template, and its maintainers are named in
the deck's CODEOWNERS.
-->

---

## Moving down, and archiving

- **Deckyard to Skiffyard:** no noticeable user base **for a year**;
  proposed in an issue, **announced a month ahead**, decided by a majority
  of the Deckyard maintainers' votes. It can come back the same way
- **Archived:** no maintainer for six months, or CI failing on the current
  release for three months with nobody working on it; announced a month
  ahead
- An archived deck keeps its releases and its name; anyone can adopt it

<!-- notes:
Demotion is not a punishment. A Skiffyard deck keeps its maintainers and
meets the same requirements; it only leaves the tier that promises a broad
user base. Archiving is different: it changes nothing for users, whose builds
keep working, but the README says the deck is unmaintained. Adopting means
contributing for a while, then asking in an issue.
-->

---

## What a move costs your users

- The deck gets a repository in the new organisation
- The registry records the move; **the old versions are yanked**
- There is **no alias**: users change the `[decks]` entry **and** every
  `import "@old/name/";`
- `jvc add`, `install` and `update` refuse the old name, naming the new one
- A lock file that pins an old version still installs, with a warning

<!-- notes:
This is why tiers matter before you publish widely. Every move breaks the
import paths of every user, by design: the old name never quietly resolves to
code from somewhere else. The 0.28.0 move from @jennifer to @deckyard worked
exactly this way. Moves are cheapest before 1.0, while a deck still has few
users, so think early about where your deck belongs.
-->

---

## How the registry finds your deck

| Field | Used for |
| --- | --- |
| name | search, ranked first |
| `description` | search, after name matches; shown in every result |
| `keywords` | tag pages: `/tags`, `/tag/<keyword>` |

- Search is a case-insensitive **substring** match on name and description;
  keywords are **not** searched
- Only the **first five** keywords count; lower case, 2 to 32 characters of
  letters, digits and single hyphens; others are silently dropped

<!-- notes:
This is from the registry's own code. A search for "router" finds a deck
named routeros first, then every deck whose description mentions routers.
Keywords group decks on tag pages, built from the newest version, so order
them by importance. A keyword such as "HTTP Client" with a space is dropped
without an error, so check the tags on your deck page after the first release.
-->

---

## Being found on GitHub

- **Topics:** Deckyard's `tools/gh-create-project.sh` sets `jennifer-lang`,
  `jennifer-deck`, the organisation's topic, then the deck's keywords;
  on your own repository, set the same with `gh repo edit --add-topic`
- **Documentation site:** the shared `docs.yml` builds `docs/` with
  Grimoire and publishes the book of the highest release tag to
  `https://<owner>.github.io/deck-<name>/`
- One-time step: **Settings, Pages, Source: GitHub Actions**
- **README:** the template's badges (tests, docs, release), a link to the
  docs, `jvc add`, a usage snippet, requirements

<!-- notes:
The same script also uses the manifest's description as the repository's
description and the Pages site as its homepage, so one good sentence serves
the registry and GitHub at once. Grimoire's book carries search and an
outline. Until your first release the workflow publishes main; afterwards
the root always shows the latest release's documentation.
-->

---

## Checklist: easy to find, easy to trust

1. **A clear name**: the format or service people search for, no
   cryptic acronym
2. **One precise sentence** as `description`: what it does, for what
3. **Up to five keywords**, the most important first
4. **Topics** on the repository: `jennifer-lang`, `jennifer-deck`, keywords
5. **A docs site** on Pages, linked from the README and `manual`
6. **A cheatsheet** with every export, checked by the gate
7. **Runnable examples**, one per subject
8. **A green badge** and a recent release

<!-- notes:
Most of this costs minutes. A name like beaufort or money is found; a name
like bwfc is not. The description should say what the deck does and with
what, the way the Deckyard list reads: "Exact currency amounts in minor
units". The cheatsheet and examples are what turn a visitor into a user,
because they answer "can I use this" in a minute.
-->

---

## Links

- Registry: [registry.jennifer-lang.dev](https://registry.jennifer-lang.dev/)
- jvc manual: [jvc.jennifer-lang.dev](https://jvc.jennifer-lang.dev/)
- Template: [jennifer-language/deck-template](https://github.com/jennifer-language/deck-template)
- Deckyard: [github.com/deckyard](https://github.com/deckyard), rules in
  [CONTRIBUTING](https://github.com/deckyard/.github/blob/main/CONTRIBUTING.md)
- Skiffyard: [github.com/skiffyard](https://github.com/skiffyard), rules in
  [CONTRIBUTING](https://github.com/skiffyard/.github/blob/main/CONTRIBUTING.md)
- Next talk: [Writing and publishing your first deck](https://academy.jennifer-lang.dev/talks/mplx/first-deck/)

Based on Jennifer 0.28.0, November 2026.

<!-- notes:
The registry's manual has a page on publishing that lists exactly what your
repository needs at the published commit, and the jvc manual covers logins,
scopes, trusted publishing and moved decks in detail. Read Deckyard's
CONTRIBUTING before you propose a deck. And look at a few published decks
before your first: money for a small one, geo or routeros for large ones.
-->

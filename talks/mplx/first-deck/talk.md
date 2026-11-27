---
theme: meridian
ratio: 16:9
transition: slide
---

# Writing and publishing your first deck

![Jennifer](jennifer-logo.png)

From an empty directory to a deck others install with `jvc`: the manifest,
the source layout, tests, the shared CI gate, a tag, and the registry.

November 2026, by [@mplx](https://github.com/mplx).\
Based on **Jennifer 0.27.0**

<!-- notes:
We build one small deck from start to finish: @mplx/beaufort, which turns a
wind speed into a Beaufort force. It is deliberately tiny, so every slide is
about the packaging and not the code. Every output on these slides is from a
real run of the template's tools on that deck, except the jvc lines, which
follow the jvc manual. The talk assumes you can write
a Jennifer function and have used jvc to install somebody else's deck.
-->

---

## What a deck is

- A **library of Jennifer modules** in its own git repository
- A **scoped name**: `@deckyard/telegram`, `@mplx/clispinner`, `@you/thing`
- Consumers get **only `src/`**, copied into their `vendor/` by `jvc`
- The **registry indexes** decks; the code stays in git, pinned to a commit

| Name | What it is | Where it comes from |
| --- | --- | --- |
| `http` (bare) | a bundled module | the interpreter, versioned with it |
| `@scope/deck` | a deck | `jvc install`, into `vendor/scope/deck/` |

<!-- notes:
Jennifer has two kinds of reusable code. Bare names like http or csv are the
modules bundled with the interpreter; you require them by requiring an
interpreter version. Everything else is a deck, with a scope in front of its
name. A deck has nothing to compile: it is source, and what a consumer
receives is exactly the src directory of the version they pinned. Tests,
docs and examples stay in your repository.
-->

---

## Start from the template

```sh
cp -r deck-template deck-beaufort && cd deck-beaufort
tools/init-deck.sh mplx beaufort "Wind speed to Beaufort force"
rm TEMPLATE.md tools/init-deck.sh tools/sync-deck.sh
```

```text
initialised @mplx/beaufort (repository github.com/mplx/deck-beaufort)
```

A working deck: one export, one test overlay, one example, docs, green CI.

<!-- notes:
deck-template in the jennifer-language organisation is a minimal deck that
already passes its own gate. init-deck.sh renames the module and rewrites the
name, the repository and the Pages URLs in every file, and writes the lock of
the shared files. The three template-only files must go: a check called
identity fails CI while any trace of the placeholder name is left. jvc init
also writes a skeleton, but without the CI layer this talk relies on. Start
the copy with a fresh git history and your own remotes.
-->

---

## deck.toml: who the deck is

```toml
[package]
name = "@mplx/beaufort"
version = "0.1.0"
description = "Wind speed to Beaufort force"
license = "LGPL-3.0-only"
capabilities = []

[package.urls]
deck = "https://raw.githubusercontent.com/mplx/deck-beaufort/main/deck.toml"

[engines]
jennifer = ">=0.27.0"
```

<!-- notes:
The manifest is the single source of truth for name, version, licence and
interpreter floor. The name is scoped and lower case; the deck half becomes
the namespace consumers write, so it is letters and digits only. The deck URL
is required for publishing. The template also fills in authors, keywords,
homepage and manual.
YAML and JSON manifests work too, but keep exactly one per repository.
-->

---

## Capabilities, engines, dependencies

- `capabilities`: `net`, `exec`, `sql`, or none. Empty means pure; it then
  also loads on `jennifer-tiny`. Give each one a comment saying why.
- `[engines] jennifer`: exactly `">=X.Y.Z"` or `">=X.Y.Z <A.B.C"`
- `[decks]`: other decks, always scoped, with a constraint

```toml
# It talks to the vendor's HTTPS API, so it opens sockets.
capabilities = ["net"]

[decks]
"@deckyard/forensicgenetics" = "^0.1.0"
```

<!-- notes:
Capabilities are enforced by the interpreter, not by trust: every source file
that needs one declares it in a pragma header, and a build without it refuses
to load the file. The engine range takes only the two forms shown; jvc picks
the newest version of your deck whose range admits the consumer's interpreter.
A dependency is always scoped. A caret constraint on a zero version, ^0.1.0,
means at least 0.1.0 and below 0.2.0.
-->

---

## src/: the part that ships

```text
src/beaufort.j          the entry module: import "@mplx/beaufort/"
src/beaufort_test.j     its white-box test overlay
```

Every `.j` file opens with the same header; `tools/check-headers.sh`
compares it with the manifest:

```text
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0
```

Two shapes: **modules** (one file per subject) or **topics** (one entry file
that `include`s `src/topics/*.j`).

<!-- notes:
The entry module must be named after the deck. A modules deck lets consumers
import a second file directly, as @scope/deck/other.j. A topics deck has one
namespace with everything in it, which reads better when there are many
subjects; the RouterOS™ deck is built that way. Only Jennifer source may live
in src, since all of it is vendored; a check refuses editor swap files and
other leftovers.
-->

---

## The code

```jennifer excerpt
/**
 * The Beaufort force of a wind speed.
 * @return {int} the force, 0 (calm) to 12 (hurricane)
 */
export func force(kmh as int) {
    if ($kmh < 0) {
        throw Error{kind: "beaufort", message: "beaufort: negative speed"};
    }
    def f as int init 0;
    while ($f < 12 and $kmh >= LIMITS[$f]) { $f = $f + 1; }
    return $f;
}
```

<!-- notes:
LIMITS, a private constant above it, holds the lowest speed of forces 1 to
12; only exported names are reachable from outside. Every
export has a docblock, and the docblock is checked: an @param for a
parameter that no longer exists fails the publish gate. Errors get a kind of
their own, here "beaufort", so callers can match the kind and never the
message; the full docblock also has @param, @throws and @example lines. A deck whose server reports a
status throws one struct with fields instead.
-->

---

## Tests: an overlay beside every module

```jennifer excerpt
func testLimitsBelongToTheForceAbove() {
    testing.assertEqual(force(38), 5);
    testing.assertEqual(force(39), 6);
}

func testNegativeSpeedThrows() {
    testing.assertThrowsArgs("force", [-1], "beaufort");
}
```

```text
$ jennifer test src/beaufort_test.j
PASS testCalm (0 ms)
...
4 passed, 0 failed, 4 total
```

<!-- notes:
An overlay is compiled together with its module, so it reaches private
helpers too. jvc refuses to publish a deck where a module has no overlay, or
an overlay defines no test. The overlays run from a copy of src alone, the
way a consumer's jvc install with runtests runs them, so fixtures belong in
src as constants, not in a testdata directory beside it.
-->

---

## The shared CI layer

`deck-template/tools/shared-files` lists what every deck carries
byte-identically: the workflows, `.github/actions/`, most of `tools/`,
`AGENTS.md`.

| Kind | Meaning |
| --- | --- |
| `shared` | copied verbatim, pinned in `tools/shared.lock` |
| `optional` | like shared, but a deck may delete it |
| `seed` / `merge` / `import` | the deck's own file, created or extended |
| `retired` | removed on the next sync |

<!-- notes:
Dozens of decks run the same checks, so the checks live in one place. The
template's sync-deck.sh writes the shared files into a deck and records a
hash of each in shared.lock. A fix to a workflow is made once, in the
template, and synced out to every deck. Seed files such as .editorconfig are
written only when the deck has none, and merge appends missing lines to
.gitignore.
-->

---

## Never edit a shared file in a deck

```text
$ tools/check-shared.sh
error: shared files differ from the template they were synced from:
  tools/check-src.sh: changed

These files are shared by every deck. Undo the local change, and either
move deck-specific logic to tools/check-extra.sh or fix the file in the
template and sync it
```

- Deck-specific checks: `tools/check-extra.sh` (run when executable)
- How examples are checked: `tools/check-examples.sh`, the deck's own

<!-- notes:
check-shared.sh runs first in CI. One appended comment line in a shared
script is enough to fail it, which is the point: a deck that drifts no longer
gets the fixes. The two files a deck owns are the escape hatches. The geo
deck runs a fuzz sweep in check-extra.sh; a deck whose examples need a live
service or a key makes check-examples.sh only parse them instead of running.
-->

---

## The gate: tools/check-all.sh

```text
@mplx/beaufort 0.1.0 - deck.toml, modules shape, tiny=no
=== shared     all 22 shared files match the template
=== format     === lint
=== headers    all 3 source files carry the SPDX pair and >=0.27.0
=== overlays   all 1 modules in src/ have a co-located test overlay
=== src        src/ holds only Jennifer source
=== coverage   all 1 exported functions are called from an overlay
=== docs       docs name 1 functions, ... all matching the code
=== identity   no template identity left in @mplx/beaufort
=== suites     4 passed, 0 failed, 4 total
=== examples   all 1 examples ran
the gate is green
```

<!-- notes:
This is the same order as CI, condensed to one line per step. Every step runs
even after one fails, so a single pass lists everything to fix. Format and
lint print nothing when they are clean. When the floor is above the installed
interpreter, set JENNIFER to a binary built from source and
JENNIFER_SYSMODDIR to its modules, and the gate uses those instead.
-->

---

## What the gate catches

A new export, `isCalm(kmh)`, with no test and no cheatsheet line:

```text
=== coverage
  src/beaufort.j: beaufort.isCalm() is exported but never called from an overlay
1 of 2 exported function(s) are untested.
=== docs
  docs/cheatsheet.md: beaufort.isCalm() has no signature in the API surface
1 documentation problem(s).
...
failed: coverage docs
```

<!-- notes:
The two checks people meet most. Coverage is a floor, not a measure: one call
from any overlay counts. The docs check reads docs/cheatsheet.md and compares
every function's name and parameters, every constant's value and every
struct's fields with the code, and parses every jennifer block in the docs
and README. A documented signature that drifted from the code fails the
build, so the cheatsheet stays true.
-->

---

## Docs, design notes, JENNIFER.md

- `README.md`: install, a usage snippet, requirements
- `docs/`: a Grimoire book; `SUMMARY.md` the outline, `cheatsheet.md` every
  export, published to Pages by `docs.yml`
- `docs/design.md`: scope, decisions and why, errors, limits, testing, known
  limitations, the interpreter features it needs
- `examples/`: one runnable program per subject; CI runs them
- `JENNIFER.md`: the language reference for coding assistants, a local copy
  whose last line must match `jennifer version`

<!-- notes:
The cheatsheet is the reference, the guides explain. The design notes are for
the next maintainer: why the deck looks the way it does, which errors it
throws and passes on, what it was tested against, and what is still open.
Keep them brief and technical, with no history section; git has that.
JENNIFER.md is a working file for assistants, kept untracked here and resynced
whenever a new interpreter build is installed.
-->

---

## Using it from another project

```toml
[decks]
"@mplx/beaufort" = "^0.1.0"
```

```sh
jvc add "@mplx/beaufort" "^0.1.0"   # writes the line above
jvc install                         # vendor/mplx/beaufort/beaufort.j
```

```jennifer
use io;
import "@mplx/beaufort/";

io.printf("force %d\n", beaufort.force(45));
```

A sibling checkout is **not** found: `@` resolves only under `vendor/`.

<!-- notes:
jvc add records the requirement; install resolves, copies src without the
overlays into vendor, and pins the result in camcorder.lock. Commit the lock,
gitignore vendor. The trailing slash imports the entry module and binds the
deck's name as the namespace. Without a vendor tree the import fails with
"needs a vendor directory", which is why an unreleased change in one deck is
invisible to the decks that depend on it.
-->

---

## Releasing: the tag is the version

```sh
# bump version in deck.toml, commit, then:
git tag 0.1.0
git push origin 0.1.0
```

- Stable SemVer, **no `v`**: `0.1.0`, never `v0.1.0`
- `release.yml` refuses a tag that differs from the manifest, a deck still
  carrying the template's identity, and a red gate
- It builds the release archive, writes the notes and starts the docs build

<!-- notes:
The tag and the manifest say the same number by rule, and CI checks it: bump
the manifest first, then tag that commit. A prerelease tag such as 0.2.0-rc1
does not trigger a release. Releasing is the maintainer's decision; never let
a tool or an assistant tag and push on its own. Tags should never move once
pushed, since published versions are pinned to what they pointed at.
-->

---

## Scopes: who may publish what

```sh
jvc login              # device flow through the registry's provider
jvc claim mplx         # your GitHub username, or an organisation of yours
jvc scopes             # who holds what
```

- `@jennifer` and `@deckyard` are reserved for the project: only a
  registry operator grants them
- An organisation scope belongs to the organisation, not to you
- Co-owners via `jvc owners <scope> <subject>`

<!-- notes:
registry.jennifer-lang.dev derives scopes from GitHub™: you may claim the scope
matching your username and one for each organisation your login carries. An
organisation that restricts third-party access must approve the registry's
application first, then you log in again. Reserved names, the project's own
included, are granted only by an operator. Official decks are @jennifer,
community decks maintained in the Deckyard organisation are @deckyard.
-->

---

## jvc publish: nothing is uploaded

```text
$ jvc publish --remote github --tag 0.1.0
checked @mplx/beaufort@0.1.0
  ok    lint: 1 module(s) clean
  ok    tests: 1 overlay(s) passed
  ok    docblocks: no doc drift
```

1. jvc runs the gate locally: lint, every overlay from a copy of `src/`,
   the docblocks
2. It sends the registry a **repository and a tag**, nothing else
3. The registry reads the manifest at that tag **through the forge's API**
   and records the commit as the pin

<!-- notes:
There is no upload and no tarball. The registry resolves the tag to a commit,
reads deck.toml there, and stores name, version, dependencies and engines
from that file, so you cannot publish into a scope your manifest does not
name. The repository comes from the origin remote; name another with --remote
when origin is a forge the registry does not read. The report is the gate's,
in the format the jvc manual shows; the publish lines follow it.
-->

---

## After the first release

- A published version is **immutable**: publishing it again is refused
  (`409`). Fix forward with a new version.
- `jvc yank @mplx/beaufort 0.1.0` hides a bad version from new resolutions;
  existing lockfiles keep working
- From CI: **trusted publishing** (no stored secret) or `$JVC_TOKEN`
- Consumers can run your overlays on their machine:
  `jvc install --runtests`

<!-- notes:
A version cannot be deleted, because deleting it would break builds that pin
it; yank is the way out. A release workflow publishes best with trusted
publishing: the CI runner mints an identity token, and the registry checks it
against a publisher registered once for the deck. A consumer's runtests runs
your overlays on their interpreter, which catches a deck that only works on
yours.
-->

---

## Checklist and read more

1. `deck.toml`: name, version, floor, capabilities with a reason
2. `src/<deck>.j` plus an overlay per module; docblocks on every export
3. Cheatsheet, design notes, an example; `tools/check-all.sh` green
4. Bump, tag `N.N.N`, push, `jvc publish`

- Template: [jennifer-language/deck-template](https://github.com/jennifer-language/deck-template)
- jvc manual: [jvc.jennifer-lang.dev](https://jvc.jennifer-lang.dev/)
- Registry: [registry.jennifer-lang.dev](https://registry.jennifer-lang.dev/)

Based on Jennifer 0.27.0, November 2026.

<!-- notes:
That is the whole path. The registry's manual has a page on publishing that
lists exactly what your repository needs at the published commit, and the
jvc manual covers trusted publishing and organisation scopes in detail. Look
at a few published decks before your first: telegram for a network client,
routeros for a topics deck, geo for its own extra checks.
-->

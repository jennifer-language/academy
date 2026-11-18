---
theme: carbon
ratio: 16:9
transition: slide
---

# One CI pipeline for GitHub, Gitea and Forgejo

![Jennifer](jennifer-logo.png)

One workflow file, three forges: fmt, lint, docblocks, tests and the
docs, for a small Jennifer app.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
GitHub Actions, Gitea Actions and Forgejo Actions all read the same workflow
syntax, so one file can serve all three. It does not run unchanged by magic,
though: the forges differ in where they look for workflows, where an action
comes from, what a runner label means, what the token is called and which
GitHub features exist at all. This talk builds the pipeline for a small app
step by step and then goes through those differences. Every command and every
output on the slides was run with the Jennifer 0.26.0 release; the forge facts
come from each forge's own documentation.
-->

---

## The example: tempo

```text
tempo/
  bin/tempo                 the launcher
  src/parse.j  format.j     two modules
  src/parse_test.j  format_test.j
  docs/  grimoire.toml      the book
  tools/check.sh  docs.sh  install-jennifer.sh  docblocks.j
  .github/workflows/ci.yml
```

```text
$ jennifer run bin/tempo 1h30m 45m 30s
2h15m30s
```

<!-- notes:
tempo is a made-up command line tool, small enough to fit on slides and real
enough to have everything a pipeline checks: two modules with docblocks, a
test overlay beside each, a launcher in bin, and a Grimoire book in docs. It
adds up durations written as hours, minutes and seconds. The interesting part
is the tools folder: four small files that hold everything the pipeline does,
so the workflow itself stays short.
-->

---

## A module with docblocks

```jennifer
use convert;

/**
 * Return seconds as hours, minutes and seconds, without zero parts.
 * @param total {int} the duration in seconds, not negative
 * @return {string} the duration, for example `1h30m`; `0s` for zero
 */
export func duration(total as int) {
    def h as int init $total // 3600;
    def m as int init $total % 3600 // 60;
    return convert.toString($h) + "h" + convert.toString($m) + "m";
}
```

<!-- notes:
This is format.j, shortened to fit the slide: the real one also adds the
seconds and leaves out the parts that are zero. The doc comment above the
function is the docblock format the standard library uses. Every @param must
name a real parameter, and every parameter needs one. The compiler does not
check that, so a renamed parameter silently leaves a lying comment behind.
That is why the pipeline checks docblocks as its own step.
-->

---

## The gate is a script, not YAML

```sh
#!/bin/sh
# The gate: the same four checks locally and in CI.
set -eu
srcs=$(ls src/*.j | grep -v '_test\.j$')
echo "== fmt";       jennifer fmt -l src/*.j bin/tempo tools/*.j
echo "== lint";      jennifer lint src/*.j bin/tempo tools/*.j
echo "== docblocks"; jennifer run tools/docblocks.j $srcs
echo "== tests"
for t in src/*_test.j; do jennifer test "$t"; done
```

<!-- notes:
The first rule for a pipeline that has to run on three forges: keep the logic
out of the workflow. tools/check.sh is plain POSIX shell. You run it before you
push, and CI runs exactly the same file, so a red build can always be
reproduced at your desk. The workflow only has to get the code and an
interpreter onto a machine and call it, and that small part is all that has to
agree with three forges.
-->

---

## Docblocks: the standard library checks them

```jennifer excerpt
import "docblock.j" as docblock;    # plus use fs, io and os
def bad as int init 0;
for (def file in os.ARGS[1..len(os.ARGS)]) {
    def text as string init fs.readString($file);
    def doc as docblock.FileDoc init docblock.parse($text);
    for (def d in $doc.diagnostics) {
        io.printf("%s:%d: %s\n", $file, $d.line, $d.message);
        $bad = $bad + 1;
    }
}
if ($bad > 0) {
    exit 1;
}
```

<!-- notes:
Jennifer ships a docblock module among its bundled modules. parse reads a
source file and returns the documentation as data, together with diagnostics
for every comment that no longer matches its code: an @param for a parameter
that does not exist, a parameter without one, an orphaned comment. The module
only reports. This dozen lines turns the report into an exit code, which is
all a CI step needs. Since it reads every function, private ones included,
nothing undocumented slips through.
-->

---

## A green run

```text
$ tools/check.sh
== fmt
== lint
== docblocks
== tests
PASS testDuration (0 ms)

1 passed, 0 failed, 1 total
PASS testRejects (0 ms)
PASS testSeconds (0 ms)

2 passed, 0 failed, 2 total
```

<!-- notes:
Silence is success for the first three checks: fmt with l lists only the files
it would change, lint prints only findings, and the docblock script prints only
drift. The test runner always reports, one line per test and a total per file.
Tests run in name order, which is why testRejects comes before testSeconds.
set e in the script stops at the first command that fails, and its exit code
becomes the exit code of the CI step.
-->

---

## A red run: what each check catches

```text
== fmt
src/parse.j
```

```text
format.j:9:1: warning: unused import: `use strings` - the `strings`
  namespace is never referenced [L106]
format.j:24:5: warning: local `unused` is declared but never
  used [L101]
```

```text
src/format.j:15: @param "secs" is not a param of duration
src/format.j:15: param "total" of duration has no @param
FAIL testSeconds (0 ms)
     [assertion] parse_test.j:4:5 assertEqual: 5400 != 5300
```

<!-- notes:
Four broken copies of tempo, one per check, with the long paths shortened. A
reindented line makes fmt list the file and exit 1. Lint warns about an import
and a local nobody uses; a warning fails the run, an info finding does not. The
docblock check catches a parameter renamed in the comment but not in the code,
from both sides. The last line is an ordinary failed assertion, with both
values.
-->

---

## Installing Jennifer: from the release

```sh
set -eu
v="$1"
stage="jennifer-$v-linux-amd64"
base="https://github.com/jennifer-language/jennifer"
base="$base/releases/download/$v"
mkdir -p .ci && cd .ci
curl -fsSLO "$base/$stage.tar.gz"
curl -fsSLO "$base/$stage.tar.gz.sha256"
sha256sum -c "$stage.tar.gz.sha256"
tar xzf "$stage.tar.gz"
echo "$PWD/$stage" >> "$GITHUB_PATH"
echo "JENNIFER_SYSMODDIR=$PWD/$stage/share/jennifer/modules" \
    >> "$GITHUB_ENV"
```

<!-- notes:
tools/install-jennifer.sh downloads a pinned release, verifies its checksum and
unpacks it into the workspace. It needs nothing but sh, curl, tar and
sha256sum, so it does not depend on what a runner image has preinstalled. The
bundled modules, docblock.j among them, sit in the tarball rather than at the
system path a package installs to, hence JENNIFER_SYSMODDIR. GITHUB_PATH and
GITHUB_ENV work on Forgejo too, where every FORGEJO variable has a GITHUB alias.
-->

---

## The book: a pinned Grimoire

```sh
#!/bin/sh
# Build the book into site/ with Grimoire release $1.
set -eu
git clone -q -c advice.detachedHead=false \
    --depth 1 --branch "$1" \
    https://github.com/jennifer-language/grimoire.git .ci/grimoire
jennifer run .ci/grimoire/bin/grimoire build
```

```text
$ tools/docs.sh 0.5.0
built 2 pages into site/ (62 KiB, 0 assets) in 9 ms
  search index: 2 sections
```

<!-- notes:
Grimoire is itself a Jennifer program, so the interpreter that just ran the
tests can also build the book: clone the release tag and run its launcher.
Grimoire 0.5.0 needs no decks, so there is nothing to vendor. The container
image is the other way, but a job that starts its own containers needs Docker
on the runner, which a forge runner does not always offer. Pinning the version
keeps next year's build identical to today's.
-->

---

## ci.yml: one gate

```yaml
on:
  push: { branches: [main] }
  pull_request:
permissions: { contents: read }
env: { JENNIFER_VERSION: 0.26.0, GRIMOIRE_VERSION: 0.5.0 }
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: tools/install-jennifer.sh "$JENNIFER_VERSION"
      - run: tools/check.sh
```

<!-- notes:
The top of the workflow and its first job run on all three forges. They use
nothing but triggers, read-only permissions, workflow-level env, checkout and
run steps: the common core every implementation supports. Both versions sit
at the top of the file, one line each to bump. The install script writes to
GITHUB_PATH, so the next step finds jennifer on its PATH without a full path.
-->

---

## ci.yml: the book, on every forge

```yaml
  docs:
    needs: check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: tools/install-jennifer.sh "$JENNIFER_VERSION"
      - run: tools/docs.sh "$GRIMOIRE_VERSION"
```

Jobs share no files: each one checks out and installs again.

<!-- notes:
The docs job builds the book on every push and every pull request, on every
forge, so a broken link or a bad outline fails the pull request instead of the
next release. It only proves that the book builds; publishing it is the next
job. Every job starts on a fresh machine, so it checks out and installs Jennifer
again. Passing files between jobs would need artifacts, and artifacts are one
of the places where the forges differ.
-->

---

## ci.yml: Pages, on GitHub only

```yaml
  pages:
    needs: check
    if: github.server_url == 'https://github.com' &&
      github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions: { contents: read, pages: write, id-token: write }
    environment: github-pages
    steps:
      # checkout, install-jennifer.sh, docs.sh: as in the docs job
      - uses: actions/upload-pages-artifact@v3
        with: { path: site }
      - uses: actions/deploy-pages@v4
```

<!-- notes:
GitHub Pages exists only on GitHub, so the deployment is a job of its own with
a job-level condition on the server URL. On Gitea and Forgejo that expression
is false and the job is skipped as a whole. The github context exists there
too: Forgejo defines it as the same as its forgejo context, and in Gitea
github dot anything is an alias of gitea dot anything. Pages itself must be
set to deploy from GitHub Actions in the repository settings.
-->

---

## Where each forge looks for workflows

| Forge | Reads |
| --- | --- |
| GitHub | `.github/workflows/` |
| Gitea | the first that exists of `WORKFLOW_DIRS`, by default `.gitea/workflows`, `.github/workflows` |
| Forgejo | `.forgejo/workflows/`; without it, `.github/workflows/` |

Never add a `.gitea/` or `.forgejo/` workflow folder to a shared repo:
the `.github/` workflows then vanish there, without a warning.

<!-- notes:
This is why one file in .github/workflows is enough. Gitea's WORKFLOW_DIRS
setting is a list, and the first folder that exists in a repository is the
only one used. Forgejo looks in .github/workflows only in the absence of a
.forgejo/workflows folder. So a single forge-specific workflow, added for a
small job, silently switches off the whole shared pipeline on that forge. Keep
one folder; branch inside it with if.
-->

---

## Turning Actions on

| Forge | By default |
| --- | --- |
| GitHub | on for a repository with workflows |
| Gitea | instance switch `[actions] ENABLED`; then still off per repository |
| Forgejo | on since Forgejo 1.21 (`[actions] ENABLED = false` to disable) |

And on Gitea and Forgejo, nothing runs without a registered runner:
`gitea-runner` or `forgejo-runner`.

<!-- notes:
The first surprise on a new Gitea is a workflow that never starts. The Gitea
documentation says it plainly: even if Actions is enabled for the instance,
repositories still disable Actions by default, so each repository has to switch
it on in its settings. GitHub brings its hosted runners; on Gitea and Forgejo
somebody registers a runner program with the instance, and only then does a
job find a machine.
-->

---

## `uses: actions/checkout@v4`: from where?

| Forge | A `uses:` without a host is fetched from |
| --- | --- |
| GitHub | `github.com` |
| Gitea | `DEFAULT_ACTIONS_URL`: `github` (default) or `self` |
| Forgejo | `DEFAULT_ACTIONS_URL`, by default `https://data.forgejo.org` |

```yaml
# Gitea and Forgejo also take a full URL:
- uses: https://data.forgejo.org/actions/checkout@v4
```

<!-- notes:
On Forgejo, actions/checkout is resolved against Forgejo's own mirror of
common actions, not against GitHub, and an administrator may point it
elsewhere. Gitea fetches from GitHub unless the administrator set it to self,
the instance itself. Both accept a full URL in uses, which GitHub does not.
So keep to widely used actions that every source carries, at a major version
tag. tempo needs only checkout and two Pages actions on GitHub.
-->

---

## `runs-on:` names a runner label

```text
ubuntu-latest:docker://docker.gitea.com/runner-images:ubuntu-latest
ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-22.04
debian:docker://docker.io/library/node:lts
macos:host
```

`<label>:<type>://<image>`: the runner's admin decides what
`ubuntu-latest` is. It is not GitHub's image.

<!-- notes:
On GitHub, ubuntu-latest is a hosted virtual machine with a long list of
preinstalled tools. On Gitea and Forgejo it is just a label that a runner was
registered with, mapped to a container image or to the host itself. These
lines are examples from the Gitea and Forgejo runner documentation. Forgejo
warns that not all the same tools will be available as GitHub provides. That is
why tempo installs Jennifer itself and assumes only sh, curl and tar.
-->

---

## Tokens, secrets and contexts

| | GitHub | Gitea | Forgejo |
| --- | --- | --- | --- |
| job token | `GITHUB_TOKEN` | `GITEA_TOKEN` | `FORGEJO_TOKEN` = `GITHUB_TOKEN` |
| context | `github.*` | `gitea.*`, `github.*` alias | `forgejo.*` = `forge.*` = `github.*` |
| reserved prefix | `GITHUB_` | `GITHUB_`, `GITEA_` (secrets) | `FORGEJO_`, `GITHUB_`, `GITEA_` (variables) |

<!-- notes:
tempo's pipeline uses no token beyond what checkout takes implicitly, which is
the easiest way to stay portable. If a step needs one, Forgejo offers it under
both names, Gitea as secrets.GITEA_TOKEN. Gitea's token cannot publish to its
own repository's package registry, so pushing an image there takes a personal
access token. Name your own secrets without the reserved prefixes, so the same
name works everywhere.
-->

---

## What only GitHub has

- **Pages:** Gitea's job token has no `pages` or `id-token` scope
- **`environment:`** is ignored by Gitea
- **Artifacts:** `upload-artifact@v4` needs Gitea Runner 3.0.0 and
  action 4.4.0 or newer; Forgejo wants v3 or its patched v4 from
  `code.forgejo.org/forgejo/upload-artifact`
- Problem matchers and error annotations: ignored by Gitea

Keep such steps in a job guarded by `github.server_url`.

<!-- notes:
These are the places where one file stops being enough. Pages deployment needs
an id-token and a pages scope that Gitea does not have, so tempo publishes its
book only from GitHub; on the other forges the docs job still proves that the
book builds. Artifacts work everywhere, but with different action versions, so
a job that passes files between jobs needs a variant per forge.
-->

---

## Checklist

- The pipeline is scripts in `tools/`; the YAML only calls them
- Pin Jennifer and Grimoire; install them from the release
- Gate: `fmt -l`, `lint`, docblocks, tests; build the book on every PR
- One folder: `.github/workflows/`, no `.gitea/` or `.forgejo/`
- Plain `actions/*` at a major tag; nothing that needs GitHub's image
- GitHub-only work in its own job with a `github.server_url` guard
- Turn Actions on per repository on Gitea; register a runner

<!-- notes:
The checklist in one sentence: make the forge as unimportant as possible.
Everything that can be a script is one, and the scripts run on your machine as
they do in CI. What remains in the YAML is the common subset of three
implementations, plus one job that only GitHub runs. When the pipeline goes red
on one forge only, look first at the runner label and at where uses fetched
its action from.
-->

---

## Read more

- Grimoire: [grimoire.jennifer-lang.dev](https://grimoire.jennifer-lang.dev/)
- Grimoire's source and its Pages workflow: [github.com/jennifer-language/grimoire](https://github.com/jennifer-language/grimoire)
- Forge docs: `docs.github.com/actions`, `docs.gitea.com/usage/actions`,
  `forgejo.org/docs/latest/user/actions`
- More talks: the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
The Gitea documentation has a page comparing Gitea Actions with GitHub Actions,
and Forgejo's actions reference lists every key it supports; both are worth
reading before you rely on a feature. The Testing talk in this academy covers
the test runner in depth, and the Grimoire talk the book and its own GitHub
Pages workflow. The project's Forgejo at git.jennifer-lang.dev runs the same
workflow files as GitHub.
-->

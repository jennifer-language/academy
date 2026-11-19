# One pipeline for GitHub, Gitea and Forgejo: the code

`tempo/` is the example project of the talk, complete: a made-up command
line tool that adds up durations, with its modules, tests, book and CI. It
runs with Jennifer 0.26.0 and needs no decks and no server. To try the
pipeline on a forge, copy `tempo/` into a new repository of its own; the
workflow expects it at the repository root. `site/` (the built book) and
`.ci/` (the downloaded interpreter and Grimoire) are generated, keep them out
of git.

- `tempo/bin/tempo`, `tempo/src/parse.j`, `tempo/src/format.j`: the tool and
  its two modules with docblocks ("The example: tempo", "A module with
  docblocks"; the slide shows `format.j` shortened).
  Run, from `tempo/`: `jennifer run bin/tempo 1h30m 45m 30s` (prints
  `2h15m30s`)
- `tempo/src/parse_test.j`, `tempo/src/format_test.j`: the test overlays.
  Run, from `tempo/`: `jennifer test src/parse_test.j`
- `tempo/tools/check.sh`: the gate, fmt, lint, docblocks and tests ("The gate
  is a script, not YAML", "A green run").
  Run, from `tempo/`: `sh tools/check.sh`
- `tempo/tools/docblocks.j`: reports docblocks that do not match their code,
  with the bundled `docblock.j` module ("Docblocks: the standard library checks
  them"). `check.sh` runs it on the non-test sources.
- `tempo/tools/install-jennifer.sh`: downloads and verifies a pinned release
  into `.ci/` and writes `GITHUB_PATH` / `GITHUB_ENV` ("Installing Jennifer:
  from the release"). Meant for CI; run locally it needs those two variables
  set to files, for example `GITHUB_PATH=/dev/null GITHUB_ENV=/dev/null sh
  tools/install-jennifer.sh 0.26.0`. Needs `curl`, `tar`, `sha256sum` and
  network access.
- `tempo/tools/docs.sh`, `tempo/grimoire.toml`, `tempo/docs/`: build the book
  with a pinned Grimoire into `site/` ("The book: a pinned Grimoire").
  Run, from `tempo/`: `sh tools/docs.sh 0.5.0` (clones Grimoire from GitHub
  into `.ci/grimoire`; remove that folder before running it again).
- `tempo/.github/workflows/ci.yml`: the one workflow with the `check`, `docs`
  and GitHub-only `pages` jobs ("ci.yml: one gate", "ci.yml: the book, on every
  forge", "ci.yml: Pages, on GitHub only"). Gitea and Forgejo read
  `.github/workflows/` too when they have no `.gitea/` or `.forgejo/` folder.
- `red-run.sh`: makes four broken copies of `tempo/`, one per check (a
  reindented line, an unused import and local, a renamed `@param`, a wrong
  expected value), and runs `tools/check.sh` in each ("A red run: what each
  check catches"). `tempo/` itself is not changed.
  Run, from this folder: `sh red-run.sh [target-dir]` (default: a new
  temporary directory, printed at the end).

# Writing and publishing your first deck: the code

The deck of the talk, `@mplx/beaufort`, and a project that uses it. Checked
with Jennifer 0.27.0, jvc 0.2.0 and deck-template at commit `c81632c`.
Nothing here is published, and nothing needs a registry account: the
consumer reads the deck from a local git repository through `[sources]`.

- `deck-beaufort/`: the files the deck author writes, laid over the
  template: `deck.toml` ("deck.toml: who the deck is"), `src/beaufort.j`
  with `LIMITS` and `force` and its full docblock ("src/: the part that
  ships", "The code"; the file is `jennifer fmt` clean, so its `while` body
  takes three lines where the slide has one), `src/beaufort_test.j` with
  the four tests ("Tests: an overlay beside every module"),
  `examples/force.j`, `docs/` (outline, introduction, cheatsheet, design
  notes), `README.md` and `grimoire.toml` ("Docs, design notes,
  JENNIFER.md"). The shared CI layer is not copied here; `make-deck.sh`
  takes it from the template.
- `make-deck.sh`: builds the complete deck the way "Start from the
  template" does (copy, `tools/init-deck.sh mplx beaufort "..."`, remove
  the three template-only files), lays `deck-beaufort/` over it, runs the
  gate ("The gate: tools/check-all.sh") and commits and tags `0.1.0` in a
  local git repository. Nothing is pushed.
  Run, from this folder: `sh make-deck.sh [template-dir] [target-dir]`
  (default: clones https://github.com/jennifer-language/deck-template into
  `./deck-beaufort-built`). Needs `git`, `bash` and `jennifer`. Then, in
  the built deck: `jennifer test src/beaufort_test.j`,
  `jennifer run examples/force.j`, `jvc pack` (the gate of "jvc publish:
  nothing is uploaded", writing a tarball into `dist/` instead of
  publishing).
- `red-gate.sh`: two broken copies of the built deck in a temporary
  directory: a new export `isCalm` with no test and no cheatsheet line, and
  a comment appended to the shared `tools/check-src.sh` ("What the gate
  catches", "Never edit a shared file in a deck").
  Run, after `make-deck.sh`: `sh red-gate.sh [deck-dir]`
- `consumer/deck.toml`, `consumer/main.j`: a project that requires the deck
  and prints `force 6` ("Using it from another project"). `[sources]` points
  at `../deck-beaufort-built`, the tagged repository `make-deck.sh` wrote.
  Run, from `consumer/`: `jvc install` (writes `vendor/mplx/beaufort/` and
  `camcorder.lock`), then `jennifer run main.j`. Without `vendor/` the
  import fails with "needs a vendor directory". `jvc install --runtests`
  also runs the deck's overlay.

Not run for the talk: `jvc login`, `jvc claim`, `jvc scopes`, `jvc publish`,
`jvc yank` and the git push of a tag, which need a registry account or a
remote repository.

# Introduction to Markdown: the code

Sample inputs for the two tools the talk is about: a small Grimoire book and
a small Cantrip deck, together holding every construct the slides show. There
is no Jennifer program here. Built and checked with Jennifer 0.26.0, Cantrip
0.4.0 and Grimoire 0.5.0, each installed with
`jvc app install https://github.com/jennifer-language/cantrip` (or
`.../grimoire`) or run from a checkout as `<checkout>/bin/cantrip`. The build
output (`site/`, `deck.html`, `deck.pdf`) is not kept here.

- `book/grimoire.toml`, `book/docs/SUMMARY.md`: a book with an
  introduction and one part of three chapters ("Grimoire: a book from a
  folder").
  Build, from `book/`: `grimoire build --pdf` (writes `site/` and
  `site/book.pdf`)
- `book/docs/markdown.md`: every slide's example on one page: headings,
  emphasis, lists, task and definition lists, links and an image, a code
  block with `title="hello.j"`, a table, a quote and a callout, an anchor, a
  class and key caps, and the unsupported cases ("Text that reads as it is"
  to "What is not supported").
- `book/docs/installation.md`: a fixed anchor `{#install}`, a link with the
  class `gr-button`, and `<!-- pagebreak -->`, which starts a new page in
  `book.pdf` only; `book/docs/commands.md` links to that anchor
  ("Anchors, classes and keys", "Grimoire: a book from a folder").
- `book/docs/index.md`, `book/docs/jennifer-logo.png`: the introduction and
  the picture the image example shows.
- `deck.md`, `jennifer-logo.png`: a five-slide Cantrip deck with front
  matter, notes and the inline extensions, key caps, a footnote, escaped
  HTML, a bare address and a `***` rule ("Cantrip: slides from one file",
  "What is not supported").
  Build, from this folder: `cantrip build deck.md` (writes `deck.html` and
  `deck.pdf`); `cantrip info deck.md` lists the slides.

What the two tools do with the less common cases, as built here:

| Input | Cantrip 0.4.0 | Grimoire 0.5.0 |
| --- | --- | --- |
| `<kbd>Ctrl</kbd>` | a key cap | escaped, shown as text |
| other inline HTML | escaped, unless `--raw-html` | always escaped |
| an HTML block | escaped, unless `--raw-html` | kept, unless `rawHtml = false` |
| `[^1]` footnote | numbered, linked, note at the end | a bare number, the note a plain paragraph |
| bare `https://` address | plain text | plain text |

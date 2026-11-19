# Slides with Cantrip: the code

Sample decks for every command the slides run, built and checked with
Cantrip 0.4.0 on Jennifer 0.26.0. Install Cantrip with
`jvc app install https://github.com/jennifer-language/cantrip`, or clone it
(`git clone --branch 0.4.0 https://github.com/jennifer-language/cantrip`) and
run `./cantrip/bin/cantrip` instead of `cantrip`. Run every command from
this folder; Cantrip writes its output beside the deck (`*.html`, `*.pdf`,
not kept here) and never creates directories, so make `public/` and `dist/`
first for the commands that write there.

- `talk.md`: "Three good habits", four slides, two with notes, theme
  `nordic` in `mode: dark` ("One file in, two files out", "Front matter sets
  up the deck", "Speaker notes", "The PDF", "When a slide is too full").
  Build: `cantrip build talk.md -v` (writes `talk.html` and `talk.pdf`);
  `cantrip info talk.md` lists the slides, a star for each with notes;
  `cantrip html talk.md --theme nosuch` shows the unknown-theme error
  (exit code 1).
- `long.md`: four slides, one of them too long for its page ("When a slide
  is too full").
  Build: `cantrip pdf long.md` (prints the overflow warning on stderr)
- `format.md`, `jennifer-logo.png`: the format in one deck: separators, an
  empty chunk that makes no slide, a `***` rule, a code block and a fence
  inside a longer fence, a note over several lines, a picture and a missing
  one, task and definition lists, a callout, the inline extensions, key
  caps, escaped HTML, a footnote, a bare address, a table ("Slides are
  separated by three dashes" to "More than bullet points").
  Build: `cantrip build format.md -v` (reports `report.png` as not found
  and draws its alt text in the PDF)
- `divide.j`: the program on the "Code blocks" slide.
  Run: `jennifer run divide.j` (stops with `division by zero` and the
  file, line and column, exit code 1)
- `intro.md`, `part2.md`: two files that make one deck with the first
  file's front matter ("The command line").
  Build: `mkdir -p dist && cantrip build intro.md part2.md -o dist/talk`

The other lines of "The command line", with `talk.md`:

```sh
mkdir -p public
cantrip html talk.md --no-notes -o public/talk.html  # audience
cantrip pdf talk.md --notes -o talk-presenter.pdf    # you
cantrip build talk.md --theme contrast --ratio 4:3   # projector
cantrip themes
```

"How the academy uses Cantrip" runs the academy's own checker on this talk,
from a checkout of the academy repository:
`jennifer run tools/check.j talks/mplx/cantrip-slides`.

# Inside a document pipeline: the code

The programs behind the slides. Run each from this folder with Jennifer 0.26.0
(`jennifer run <file>.j`); they use only the modules bundled with the
interpreter. Programs that write files put them in the current folder:
`book.j` writes `notes.pdf`, `unicode.j` writes `unicode.pdf`, `glyphs.j`
writes `kern.svg`. Those are build output and not part of this folder; run the
program to regenerate them.

Fonts are not shipped here. `metrics.j`, `glyphs.j`, `unicode.j` and
`badfont.j` read DejaVu Sans from `/usr/share/fonts/TTF/DejaVuSans.ttf` (the
`ttf-dejavu` package; Bitstream Vera licence, DejaVu changes in the public
domain, see `/usr/share/licenses/ttf-dejavu/LICENSE`). `badfont.j` also reads
`/usr/share/fonts/cantarell/Cantarell-VF.otf` (SIL Open Font License) to show a
variable CFF2 font being refused. Change the paths for other systems.

- `walk.j`: dumps the tree `markdown.parse` builds and tries the selectors
  ("Looking at a tree", "Selectors are paths, not searches").
- `same.j`: one admonition in Markdown, MyST and rST, the same node and HTML
  ("Three readers, one tree").
- `directives.j`: MyST targets, directives and roles, the tree and `check`
  ("MyST: directives, roles, targets").
- `restructured.j`: the same document in rST, `rst.title` and `rst.check`
  ("reStructuredText: the same shapes").
- `number.j`: the two-pass figure-numbering transform ("A transform: value
  semantics shape it", "Pass 2: rebuild with numbers").
- `toc.j`: a table-of-contents transform ("A table of contents in the tree").
- `book.j` with `notes.md`: a MyST file to an A4 PDF with fills, bookmarks and
  a page footer ("PDF: PdfOptions", "The page it produced"). The slide image
  was made with `pdftoppm -f 1 -l 1 -r 80 -x 0 -y 0 -W 662 -H 360 -png notes.pdf crop`.
- `unicode.j`: Polish, Greek and Russian text in an embedded TrueType font
  ("Why Unicode text needs an embedded font"); image: `pdftoppm -r 100 -png unicode.pdf uni`.
- `metrics.j`: font metrics, glyph ids, kerning, an outline ("The font module").
- `glyphs.j`: a word as SVG outlines, without and with kerning ("Outlines and
  kerning, by hand"); image: `rsvg-convert -w 440 -b white kern.svg -o kern.png`.
- `hostile.j` and `badfont.j`: nesting caps of the three readers and a
  truncated font ("Hostile input: caps, and kind limit").
- `quotes.j`, `inline.j` and `guard.j`: the 0.26.0 PDF quote-fill slowdown,
  the silent 32-level emphasis cap, and a depth guard ("Sharp edges in
  0.26.0"). `quotes.j` takes several seconds.
- `big.j`: times parse, HTML and PDF of a 41 KiB document ("Performance:
  measure a big document"). Profile it with `jennifer profile big.j` and
  `jennifer profile --allocs big.j`.

# Making PDFs with Jennifer: the code

The programs behind the slides. They use only the `pdf` module that ships
with the interpreter, need no decks and no network, and run with Jennifer
0.26.0. Run them from this folder or any other: each writes its PDF into the
current directory. `pdftotext` (poppler) and `qpdf` are only needed to look
at the results the way the slides do.

- `hello.j`: one A4 landscape page with a title, a coloured rule and an
  outlined box ("Hello, PDF").
  Run: `jennifer run hello.j` (writes `hello.pdf`)
- `fonts.j`: `measureText` widths, the error for a font outside the
  standard 14, the error for a character outside Windows-1252, and
  `toWinAnsi` ("Fonts and measuring", "The limit: WinAnsi").
  Run: `jennifer run fonts.j` (prints only)
- `stock.j`: the whole report, 130 made-up articles on 4 pages: the layout
  constants, `rightText` and `money`, `clip` with an ellipsis, `newPage`
  with the repeated header, the row loop with page breaks, the "Page x of
  y" footers in a second pass, metadata and a bookmark ("What we are
  building" to "Metadata, bookmarks, same bytes"). It prints
  `130 rows on 4 pages` and the file size.
  Run: `jennifer run stock.j` (writes `stock-list.pdf`), then
  `qpdf --check stock-list.pdf` or `pdftotext -layout stock-list.pdf -`
- `footer.j`: a two-page document with a `PageLabel` footer that the module
  stamps at render time ("Or let the module stamp it").
  Run: `jennifer run footer.j` (writes `footer.pdf`), then
  `pdftotext -layout footer.pdf -`
- `busy.j`: rows drawn with one `pdf.text` call each and with `DrawOp`
  values applied by one `pdf.draw`, compared byte for byte, plus
  `textBlock` and `wrapText` ("When pages get busy").
  Run: `jennifer run busy.j` (writes `busy.pdf`)

# CSV and spreadsheets: the code

The programs behind the slides, for Jennifer 0.27.0. The CSV part uses the
bundled `csv.j` module; the spreadsheet part uses the `@deckyard/sheets` deck
listed in `deck.toml`, so run `jvc install` once in this folder to fill
`vendor/`. No server is needed. Run everything from this folder: the
programs read and write their files by relative path.

- `sales.csv`: the till export, with a comment line, `;` separators, quoted
  fields and padding ("A real export"). `bad.csv`: the same with two broken
  records.
- `parse.j`: `csv.parse` on RFC 4180 input, and the errors for a short
  record, a stray quote and text after a closing quote ("csv.parse: RFC
  4180", "Strict: a broken file is an error"). Run: `jennifer run parse.j`
- `dialect.j`: a dialect with `;`, `#` comments and trimming, written back as
  plain CSV ("A dialect for the file"). Run: `jennifer run dialect.j`
- `stream.j`: a streaming reader that skips the bad records of `bad.csv`
  ("Streaming, and reading past bad records"). Run: `jennifer run stream.j`
- `aggregate.j`: records, revenue per branch, and `formatSafe` against
  formula injection ("Records, cleaning, totals", "Writing CSV for a
  spreadsheet: formatSafe"). Run: `jennifer run aggregate.j`
- `build.j`: builds the "Week 44" sheet from `sales.csv` with formulas, a
  number format and bold headers, recalculates and saves `week44.xlsx`
  ("Building the sheet", "Number formats and styles", "Recalculate and save
  as XLSX"). Run: `jennifer run build.j`
- `readback.j`: opens `week44.xlsx` and reads the total's formula, cached
  value and display text ("Reading it back"). Run after `build.j`:
  `jennifer run readback.j`
- `errors.j`: `#DIV/0!` as a value, a malformed formula, the nesting cap
  (kind `"limit"`) and a file that is not a ZIP; writes `fake.xlsx` ("Errors:
  values and throws"). Run after `build.j`: `jennifer run errors.j`
- `sheetnames.j`: a reference to a missing sheet is `#REF!` in a formula and
  a throw from the API ("Errors: values and throws"). Run after `build.j`:
  `jennifer run sheetnames.j`
- `makeyear.j`: writes `year.xlsx`, a 20,001-row sheet for the streaming
  slide. Run: `jennifer run makeyear.j`
- `streamsheet.j`: reads `year.xlsx` row by row and sums a column ("Streaming
  a large sheet"). Run after `makeyear.j`: `jennifer run streamsheet.j`
- `export.j`: writes the sheet as `week44.html`, `week44.jsonl` and
  `week44.pdf` ("Export: HTML, JSON, PDF"). Run after `build.j`:
  `jennifer run export.j`

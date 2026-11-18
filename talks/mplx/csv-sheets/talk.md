---
theme: meridian
ratio: 16:9
transition: slide
---

# CSV and spreadsheets in Jennifer

![Jennifer](jennifer-logo.png)

From a messy till export to an XLSX with formulas and number formats: the
`csv` module and the `@deckyard/sheets` deck.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
Almost every program that touches business data meets a CSV file sooner or
later, and the person on the other end usually wants a spreadsheet back. This
talk follows one small file through both: read a messy export with the csv
module from the standard library, clean and total it, then build a real XLSX
with a formula and number formats using the sheets deck, read it back, stream a
large sheet and export it. The bakery and its numbers are invented, and every
output on these slides is from a real run.
-->

---

## The plan

| Step | Tool |
| --- | --- |
| Read a messy CSV, strictly | `csv.parseDialect`, `csv.reader` |
| Clean and total it | `csv.toRecords`, `convert` |
| Hand a CSV back safely | `csv.formatSafe` |
| Build an XLSX with a formula and formats | `sheet.sheetOf`, `sheet.save` |
| Read it back, stream a big one | `sheet.open`, `sheet.openRows` |
| Export for the web and for paper | `sheet.toHtmlDocument`, `toPdf` |

<!-- notes:
Two layers. The csv module ships with the interpreter: it knows quoting and
delimiters and turns text into rows of strings, nothing more. The sheets deck
is a community deck from the deckyard scope: it reads and writes ODS, XLSX and
Gnumeric files over one cell model, evaluates formulas and applies number
formats. Neither needs a network, a subprocess or an office suite installed,
which also means they run in CI and inside a container.
-->

---

## csv.parse: RFC 4180

```jennifer
use io;
import "csv.j" as csv;

def rows as list of list of string init
    csv.parse("name,note\n\"Doe, J\",\"said \"\"hi\"\"\"");
io.printf("%d rows; [%s] [%s]\n", len($rows), $rows[1][0], $rows[1][1]);
```

```text
2 rows; [Doe, J] [said "hi"]
```

Every field is a `string`. A quoted field may hold the delimiter, a doubled
quote and line breaks.

<!-- notes:
The csv module is a `.j` module, so it is imported by file name rather than
with `use`. `parse` returns a list of rows, each a list of strings: the module
does no type guessing, because a column of postcodes or article numbers must
not lose its leading zeros. The quoting rules are those of RFC 4180: a field in
double quotes may contain the comma, a line break, or a quote written twice.
Records may end in CRLF, LF or a bare CR.
-->

---

## Strict: a broken file is an error

```jennifer excerpt
for (def bad in ["a,b\n1", "a,b\n5\" disk,2", "\"ab\"c"]) {
    try {
        csv.parse($bad);
    } catch (e) {
        io.printf("%s: %s\n", $e.kind, $e.message);
    }
}
```

```text
csv: csv: record 2 has 1 fields, expected 2
csv: csv: a quote inside an unquoted field at line 2, column 2
csv: csv: text after a closing quote at line 1, column 5
```

<!-- notes:
Since 0.26.0 the parser refuses what it cannot read exactly. A short record, a
stray quote in the middle of a field and text after a closing quote each throw
an error of kind "csv" with the line and column. Older versions padded and
guessed, which is how a shifted column ends up in a report nobody checks.
Decide on the kind, never on the message: the kind is the contract, the text is
for the person reading the log.
-->

---

## A real export

```text
# export from the till, week 44
branch;product;qty;price
North;"Rye bread; sliced";12;3.20
North;Croissant;30;1.10
 South ; "Tart ""lemon""" ;8;4.50
South;Croissant;25;1.10
```

- semicolons, because the till runs in a comma-decimal locale
- a comment line, padding around fields, quotes inside quotes

<!-- notes:
This is what such files look like in practice. The till writes semicolons
because in many European locales the comma is the decimal separator; this one
still writes a dot in the prices. There is a comment line on top, someone
padded a row with spaces, and a product name contains both a semicolon and
quotes. Plain `parse` would reject this file, and rightly so: we have to tell
the reader which dialect it is looking at.
-->

---

## A dialect for the file

```jennifer excerpt
def d as csv.Dialect init csv.dialect(";");
$d.comment = "#";
$d.trim = true;
def rows as list of list of string init
    csv.parseDialect(fs.readString("sales.csv"), $d);
for (def r in $rows) { io.printf("%s\n", csv.format([$r])); }
```

```text
branch,product,qty,price
North,Rye bread; sliced,12,3.20
North,Croissant,30,1.10
South,"Tart ""lemon""",8,4.50
South,Croissant,25,1.10
```

<!-- notes:
A `csv.Dialect` collects the non-standard settings: the delimiter, the quote
character, a comment prefix, whether to trim unquoted fields, and the record
width. Trim removes the padding around South but keeps quoted content exactly.
Printing each row through `csv.format` shows the result as standard
comma-separated CSV: the semicolon is now ordinary content, and the inner
quotes are doubled again. The width rule still applies: every record must have
four fields.
-->

---

## Streaming, and reading past bad records

```jennifer excerpt
def r as csv.Reader init
    csv.readerWith(fs.open("bad.csv", "read"), ";");
while (not csv.readerEof($r)) {
    try { io.printf("ok:   %s\n", csv.readRow($r)[0]); }
    catch (e) { io.printf("skip: %s (%s)\n", $e.message, $e.kind); }
}
csv.closeReader($r);
```

```text
ok:   branch
ok:   North
skip: csv: a quote inside an unquoted field at line 3, column 8 (csv)
skip: csv: record 4 has 3 fields, expected 4 (csv)
ok:   East
```

<!-- notes:
For a file too large to hold in memory, `csv.reader` wraps an open file and
returns one record per `readRow`. A malformed record is consumed before its
error is thrown, so a loop that catches the error can log it and read on. Here
a row with an inch mark in a product name and a row missing its price are
reported with their positions, and the good rows around them still arrive.
Whether to skip or to stop is your decision, not the parser's.
-->

---

## Records, cleaning, totals

```jennifer excerpt
def recs as list of map of string to string init
    csv.toRecords(csv.parseDialect(fs.readString("sales.csv"), $d));
def revenue as map of string to float init {};
for (def rec in $recs) {
    def b as string init $rec["branch"];
    if (not maps.has($revenue, $b)) { $revenue[$b] = 0.0; }
    $revenue[$b] = $revenue[$b] +
        convert.toFloat($rec["qty"]) * convert.toFloat($rec["price"]);
}
```

```text
North 71.40
South 63.50
```

<!-- notes:
`toRecords` takes the first row as the header and gives one map per record,
keyed by column name; it throws a csv error on a duplicate column name or a
record of the wrong width. Conversion is explicit: `convert.toFloat` throws on
text that is not a number, so a price like "n/a" stops the run instead of
counting as zero. A missing map key is an error too, so the total is
initialised with `maps.has` before the first addition.
-->

---

## Writing CSV for a spreadsheet: formatSafe

```jennifer excerpt
io.printf("%s\n", csv.formatSafe([["note"],
    ["=HYPERLINK(\"x\")"], ["-5 kg"]]));
```

```text
note
"'=HYPERLINK(""x"")"
'-5 kg
```

- a field starting with `=`, `+`, `-`, `@`, tab or CR is a formula to Excel
- `formatSafe` prefixes it with `'`: literal text on import
- `format` writes it unchanged: only for programs, never for people

<!-- notes:
CSV formula injection is a classic: a customer types a formula into a web form,
an employee exports the table and opens it in a spreadsheet, and the formula
runs. Quoting does not help, the spreadsheet strips the quotes first. The
module's answer is `formatSafe`, which neutralises any field whose first
character could start a formula. Use plain `format` only when another program
reads the file as data. The sheets deck has the same pair: `writeCsv` and
`writeCsvSafe`.
-->

---

## @deckyard/sheets: one cell model

```text
$ jvc add @deckyard/sheets && jvc install
```

```jennifer excerpt
import "@deckyard/sheets/" as sheet;
```

| `sheet.Value` variant | Built with |
| --- | --- |
| `Text`, `Number`, `Bool` | `text(s)`, `number(f)`, `integer(i)`, `boolean(b)` |
| `Stamp` | `date(t)`, `stamp(t)` |
| `Formula` | `formula("SUM(A1:A9)", cached)` |
| `Err`, `Empty` | `errorValue("#N/A")`, `empty()` |

<!-- notes:
The deck is in the public registry; jvc copies its sources into the project's
vendor directory, and the import names the deck. A workbook is a list of
sheets, a sheet is a map of cells keyed by their A1 address, and every cell
holds a `Value`: an enum with one variant per kind of content. A formula cell
stores its expression without the equals sign plus the result the producing
application last computed, which is what Excel shows before it recalculates.
-->

---

## Building the sheet

```jennifer excerpt
for (def rec in $recs) {          # $lines holds the header row
    def at as string init convert.toString(len($lines) + 1);
    $lines[] = [sheet.text($rec["branch"]), sheet.text($rec["product"]),
        sheet.integer(convert.toInt($rec["qty"])),
        sheet.number(convert.toFloat($rec["price"])),
        sheet.formula("C" + $at + "*D" + $at, "")];
}
def last as string init convert.toString(len($lines));
$lines[] = [sheet.text("Total"), sheet.empty(), sheet.empty(),
    sheet.empty(), sheet.formula("SUM(E2:E" + $last + ")", "")];
def s as sheet.Sheet init sheet.sheetOf("Week 44", $lines);
```

<!-- notes:
Collect the rows first and build the sheet in one pass with `sheetOf`. Values
are copied in Jennifer, so calling `setCell` or `addRow` once per row in a loop
copies the growing cell map each time, which is quadratic. Quantities become
numbers, prices floats, and each revenue cell is a formula, `C2*D2` and so on,
with an empty cached result. The row number comes from the list's length, and a last row totals the column
with `SUM`.
-->

---

## Number formats and styles

```jennifer excerpt
def money as sheet.Style init
    sheet.withFormat(sheet.style(), "#,##0.00");
def bold as sheet.Style init sheet.withBold(sheet.style(), true);
$s = sheet.setAreaStyle($s, "D2:E6", $money);
$s = sheet.setAreaStyle($s, "A1:E1", $bold);
```

| Code | 1234.567 shows as |
| --- | --- |
| `#,##0.00` | `1,234.57` |
| `0.0%` | `123456.7%` |
| `0.00;(0.00)` | negative numbers in brackets |
| `d mmm yyyy` | a date, from a date serial |

<!-- notes:
A cell's value and what a person sees are different things. The value 3.2
stays 3.2; the format code in the cell's style says to show it with two decimal
places and a thousands separator. Styles are values too, built from the
default with `with` functions, and `setAreaStyle` applies one style to a range
in a single copy of the sheet. The format engine was checked against
LibreOffice and Gnumeric, and `applyFormatIn` renders in another locale.
-->

---

## Recalculate and save as XLSX

```jennifer excerpt
def wb as sheet.Workbook init sheet.addSheet(sheet.newWorkbook(), $s);
$wb = sheet.putSheet($wb, sheet.recalculate($wb, "Week 44").sheet);
sheet.save($wb, "week44.xlsx");
```

```text
wrote week44.xlsx, 2727 bytes
```

- `save` picks the format from the extension: `.xlsx`, `.ods`, `.gnumeric`
- `recalculate` fills the cached results; about 110 functions are known
- without it, the file carries empty caches and the application computes

<!-- notes:
`recalculate` evaluates every formula on the sheet and writes the results into
their caches, so a program reading the file later, or a viewer that does not
compute, sees the totals. Leaving the cache empty is also honest: the
spreadsheet application recalculates on open. A stale cache is the one thing to
avoid: changing a cell later with `setCell` leaves the old result in every
formula that depends on it, so recalculate again before saving. The same
workbook saves as ODS or Gnumeric by changing the file name.
-->

---

## Reading it back

```jennifer excerpt
def s as sheet.Sheet init
    sheet.sheetByName(sheet.open("week44.xlsx"), "Week 44");
def total as sheet.Value init sheet.cell($s, "E6");
match ($total) {
    when Formula(f) { io.printf("%s = %s\n", $f.source, $f.cached); }
    else { }
}
io.printf("value %s, shown %s\n", sheet.asString($total),
    sheet.displayAt($s, "E6"));
```

```text
SUM(E2:E5) = 134.9
value 134.9, shown 134.90
```

<!-- notes:
`open` reads a file by its extension; `openDetected` looks at the content
instead. A `match` on the value gives access to the formula's source and its
cached result. `asString` returns the value, 134.9, for a program;
`displayAt` shows the cell as a person would see it, through its format,
134.90. `displayRow` and `displayRows` do the same for a row or the whole
sheet, and are much cheaper than a loop of single cells.
-->

---

## Errors: values and throws

```jennifer excerpt
sheet.asString(sheet.evaluate($wb, "Week 44", "E6/0"));    # #DIV/0!
sheet.evaluate($wb, "Week 44", "SUM(E2:E5");                # throws
sheet.evaluate($wb, "Week 44", $seventyNestedBrackets);     # throws
sheet.sheetByName($wb, "Week 9");                           # throws
sheet.open("fake.xlsx");                                    # throws
```

```text
sheets: the argument list of "SUM" is never closed
limit: the formula nests deeper than 64 levels
sheets: the workbook has no sheet named "Week 9" (it has "Week 44")
sheets: not a readable ZIP container: archive.unpack: zip: not a
  valid zip file
```

<!-- notes:
Inside a formula, errors are values, exactly as in a spreadsheet: division by
zero gives `#DIV/0!` and IFERROR can catch it. The deck throws only when the
caller is at fault or the file is broken, always with kind "sheets", except
for a reached cap, which is kind "limit" like everywhere else in Jennifer. A
formula nested deeper than 64 levels or a file whose XML nests too deeply is
refused before it can exhaust the interpreter.
-->

---

## Streaming a large sheet

```jennifer excerpt
def r as sheet.RowReader init sheet.openRows("year.xlsx", "Year");
while (sheet.hasRow($r)) {
    $r = sheet.nextRow($r);
    if (sheet.rowNumber($r) == 1) { continue; }      # the header
    $total = $total + sheet.asNumber(sheet.rowValues($r)[1]);
}
```

```text
20001 rows, 390000 items
```

- one row at a time; the reader is a value, nothing to close
- ODS and XLSX stream; Gnumeric and CSV are read whole, same loop

<!-- notes:
`open` builds the whole workbook in memory, a map entry per cell. For hundreds
of thousands of cells, `openRows` walks the sheet's XML a row at a time
instead. The deck's own measurement: a 500,000-cell sheet needs 5 GB as an XML
tree and under 150 MB with `openRows`. The reader is a plain value that you
advance by assigning `nextRow`'s result. Here twenty thousand rows took about
twenty seconds on a laptop: fine for a nightly job, not for a request handler.
-->

---

## Export: HTML, JSON, PDF

```jennifer excerpt
fs.writeString("week44.html", sheet.toHtmlDocument($s, "Week 44"));
fs.writeString("week44.jsonl", sheet.toJsonLines($s));
fs.writeBytes("week44.pdf", sheet.toPdf($s, sheet.a4()));
```

```text
{"Branch":"North","Product":"Rye bread; sliced","Qty":"12",
  "Price":"3.2","Revenue":"38.400000000000006"}
{"Branch":"Total","Product":"","Qty":"","Price":"","Revenue":"134.9"}
```

- HTML and PDF show cells through their formats: `38.40`
- JSON carries values, as strings: round in the formula if it matters

<!-- notes:
Three one-way exports. The HTML page and the PDF table use the styles and the
number formats, so they show what the spreadsheet shows, and the PDF repeats
the header on every page. JSON is for programs, so it carries the value as
text, and there the binary float shows: 12 times 3.2 is not exactly 38.4.
Write `ROUND(C2*D2,2)` when the stored value itself must be cents. Every export
refuses a sheet above 100,000 rows with kind "limit".
-->

---

## Read more

- `csv` module: `docs/modules/csv.md` in the
  [Jennifer repository](https://github.com/jennifer-language/jennifer)
- The deck: [deckyard/deck-sheets](https://github.com/deckyard/deck-sheets),
  in the [registry](https://registry.jennifer-lang.dev/) as `@deckyard/sheets`
- Guides there: streaming, number formats, evaluation, untrusted files
- This talk: in the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
The csv module's page lists every dialect option and the streaming writer. The
sheets deck has guides for each part shown here, and one more worth reading
before you accept spreadsheets from strangers: reading untrusted files, with
the caps on sizes, nesting and formula growth. Take home the order of work:
read strictly, convert explicitly, write safely, and let the format code, not
the value, decide what people see.
-->

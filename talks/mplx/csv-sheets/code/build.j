use io;
use fs;
use convert;
import "csv.j" as csv;
import "@deckyard/sheets/" as sheet;

def d as csv.Dialect init csv.dialect(";");
$d.comment = "#";
$d.trim = true;
def recs as list of map of string to string init
    csv.toRecords(csv.parseDialect(fs.readString("sales.csv"), $d));

def lines as list of list of sheet.Value init [];
$lines[] = [sheet.text("Branch"), sheet.text("Product"), sheet.text("Qty"),
    sheet.text("Price"), sheet.text("Revenue")];
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

def money as sheet.Style init
    sheet.withFormat(sheet.style(), "#,##0.00");
def bold as sheet.Style init sheet.withBold(sheet.style(), true);
$s = sheet.setAreaStyle($s, "D2:E6", $money);
$s = sheet.setAreaStyle($s, "A1:E1", $bold);
def wb as sheet.Workbook init sheet.addSheet(sheet.newWorkbook(), $s);
$wb = sheet.putSheet($wb, sheet.recalculate($wb, "Week 44").sheet);
sheet.save($wb, "week44.xlsx");
io.printf("wrote week44.xlsx, %d bytes\n", len(fs.readBytes("week44.xlsx")));

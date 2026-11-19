use io;
import "@deckyard/sheets/" as sheet;

def s as sheet.Sheet init
    sheet.sheetByName(sheet.open("week44.xlsx"), "Week 44");
def total as sheet.Value init sheet.cell($s, "E6");
match ($total) {
    when Formula(f) { io.printf("%s = %s\n", $f.source, $f.cached); }
    else { }
}
io.printf("value %s, shown %s\n", sheet.asString($total), sheet.displayAt($s, "E6"));

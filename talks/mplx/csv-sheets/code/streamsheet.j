use io;
import "@deckyard/sheets/" as sheet;

def total as float init 0.0;
def r as sheet.RowReader init sheet.openRows("year.xlsx", "Year");
while (sheet.hasRow($r)) {
    $r = sheet.nextRow($r);
    if (sheet.rowNumber($r) == 1) {
        continue;                     # the header
    }
    $total = $total + sheet.asNumber(sheet.rowValues($r)[1]);
}
io.printf("%d rows, %f|prec=0 items\n", sheet.rowNumber($r), $total);

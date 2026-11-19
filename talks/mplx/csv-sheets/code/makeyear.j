import "@deckyard/sheets/" as sheet;

def lines as list of list of sheet.Value init [[sheet.text("day"), sheet.text("qty")]];
for (def i in 0..20000) {
    $lines[] = [sheet.integer($i % 365 + 1), sheet.integer($i % 40)];
}
def wb as sheet.Workbook init sheet.addSheet(sheet.newWorkbook(), sheet.sheetOf("Year", $lines));
sheet.save($wb, "year.xlsx");

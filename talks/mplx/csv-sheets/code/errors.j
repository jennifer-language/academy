use io;
use fs;
use strings;
import "@deckyard/sheets/" as sheet;

def wb as sheet.Workbook init sheet.open("week44.xlsx");
io.printf("%s\n", sheet.asString(sheet.evaluate($wb, "Week 44", "E6/0")));
def deep as string init strings.repeat("(", 70) + "1" + strings.repeat(")", 70);
for (def src in ["SUM(E2:E5", "'Week 9'!A1", $deep]) {
    try {
        sheet.evaluate($wb, "Week 44", $src);
    } catch (e) {
        io.printf("%s: %s\n", $e.kind, $e.message);
    }
}
fs.writeString("fake.xlsx", "not a zip");
try {
    sheet.open("fake.xlsx");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}

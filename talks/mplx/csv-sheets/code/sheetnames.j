use io;
import "@deckyard/sheets/" as sheet;
def wb as sheet.Workbook init sheet.open("week44.xlsx");
io.printf("%s\n", sheet.asString(sheet.evaluate($wb, "Week 44", "'Week 9'!A1")));
try { sheet.evaluate($wb, "Week 9", "A1"); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
try { sheet.sheetByName($wb, "Week 9"); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }

use io;
use fs;
import "@deckyard/sheets/" as sheet;

def s as sheet.Sheet init sheet.sheetByName(sheet.open("week44.xlsx"), "Week 44");
fs.writeString("week44.html", sheet.toHtmlDocument($s, "Week 44"));
fs.writeString("week44.jsonl", sheet.toJsonLines($s));
fs.writeBytes("week44.pdf", sheet.toPdf($s, sheet.a4()));
io.printf("%s", fs.readString("week44.jsonl"));

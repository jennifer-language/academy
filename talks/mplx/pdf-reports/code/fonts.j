# "Fonts and measuring" and "The limit: WinAnsi": text widths, the error
# for a font outside the standard 14, the error for a character outside
# Windows-1252, and toWinAnsi. Prints only, writes no file.
#
# Run: jennifer run fonts.j
import "pdf.j" as pdf;
use io;

def const FONT as string init "Helvetica";
def const SIZE as int init 8;

io.printf("%v\n", pdf.measureText("Helvetica", 8, "Hello"));   # 18.224
io.printf("%v\n", pdf.measureText("Helvetica", 8, "..."));     # 6.672
io.printf("%v\n", pdf.measureText("Helvetica", 8, "…"));       # 8.0

def pg as pdf.Page init pdf.page(842, 595);
try {
    $pg = pdf.text($pg, 110, 500, "Arial", SIZE, "Linz");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
try {
    $pg = pdf.text($pg, 110, 500, FONT, SIZE, "Gdańsk");   # throws:
} catch (e) {
    io.printf("%s\n", $e.message);
}
io.printf("%s\n", pdf.toWinAnsi("Gdańsk → Kraków", "?"));
# a clean string comes back unchanged
io.printf("%s\n", pdf.toWinAnsi("Kraków, 12 €", "?"));

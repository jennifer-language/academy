# "When pages get busy": the same rows drawn with one pdf.text call each
# and with a list of DrawOp values applied by one pdf.draw call; the two
# pages are byte-identical. A paragraph under the table with textBlock.
# Writes busy.pdf.
#
# Run: jennifer run busy.j
import "pdf.j" as pdf;
use fs;
use io;

def const FONT as string init "Helvetica";
def const SIZE as int init 8;

def struct Row { y as int, sku as string };

def rows as list of Row init [];
for (def i in 0..40) {
    $rows[] = Row{y: 520 - 12 * $i, sku: "A-{1000 + 7 * $i}"};
}

# One call per element: each one appends to the page's content.
def slow as pdf.Page init pdf.page(842, 595);
for (def r in $rows) {
    $slow = pdf.text($slow, 44, $r.y, FONT, SIZE, $r.sku);
}

# The same elements collected and applied at once.
def pg as pdf.Page init pdf.page(842, 595);
def ops as list of pdf.DrawOp init [];
for (def r in $rows) {
    $ops[] = pdf.DrawOp.Text{x: 44, y: $r.y, font: FONT,
        size: SIZE, str: $r.sku};
}
$pg = pdf.draw($pg, $ops);

def a as bytes init pdf.render(pdf.addPage(pdf.document(), $slow));
def b as bytes init pdf.render(pdf.addPage(pdf.document(), $pg));
io.printf("text calls and draw give the same bytes: %v\n", $a == $b);

# A paragraph wrapped into a 300 point column, justified.
$pg = pdf.textBlock($pg, 440, 520, 300, FONT, SIZE, 11,
    "Prices are per unit and exclude VAT. Quantities are counted at the "
    + "close of business on the last working day of the month; goods in "
    + "transit between stores are listed under the receiving store.",
    "justify");
for (def l in pdf.wrapText(FONT, SIZE, "Short lines wrap at word boundaries.", 80)) {
    io.printf("%s\n", $l);
}
fs.writeBytes("busy.pdf", pdf.render(pdf.addPage(pdf.document(), $pg)));

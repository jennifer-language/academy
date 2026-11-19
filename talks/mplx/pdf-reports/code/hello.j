# "Hello, PDF": one A4 landscape page with a title, a coloured rule and an
# outlined box. Writes hello.pdf.
#
# Run: jennifer run hello.j
import "pdf.j" as pdf;
use fs;

def pg as pdf.Page init pdf.page(842, 595); # A4 landscape
$pg = pdf.text($pg, 40, 540, "Helvetica-Bold", 20, "Stock list");
$pg = pdf.color($pg, 0, 90, 160);
$pg = pdf.line($pg, 40, 530, 802, 530);
$pg = pdf.rect($pg, 40, 470, 200, 40, false); # false: outline only

def doc as pdf.Document init pdf.addPage(pdf.document(), $pg);
$doc = pdf.info($doc, "Title", "Stock list");
fs.writeBytes("hello.pdf", pdf.render($doc));

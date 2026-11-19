# "Or let the module stamp it": a two-page document whose footer the
# module draws at render time, with %page% and %pages% filled in.
# Writes footer.pdf; `pdftotext -layout footer.pdf -` shows the footers.
#
# Run: jennifer run footer.j
import "pdf.j" as pdf;
use fs;

def doc as pdf.Document init pdf.document();
for (def n in 1..3) {
    def pg as pdf.Page init pdf.page(842, 595);
    $pg = pdf.text($pg, 40, 540, "Helvetica-Bold", 14, "Page body {$n}");
    $doc = pdf.addPage($doc, $pg);
}

def f as pdf.PageLabel init pdf.pageLabel();
$f.left = "Example Hardware Ltd.";
$f.right = "Page %page% of %pages%";
$f.border = true;
$doc = pdf.setFooter($doc, $f);   # also setHeader

fs.writeBytes("footer.pdf", pdf.render($doc));

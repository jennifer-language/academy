use fs;
import "myst.j" as myst;
import "doctree.j" as doctree;
import "pdf.j" as pdf;

func options() {
    def o as doctree.PdfOptions init doctree.pdfDefaults();
    $o.pageWidth = 595; # A4
    $o.pageHeight = 842;
    $o.margin = 56;
    $o.bodyFont = "Times-Roman";
    $o.boldFont = "Times-Bold";
    $o.italicFont = "Times-Italic";
    $o.headingStyles = [
        doctree.headingStyle(doctree.rgb(214, 228, 240)),
        doctree.headingStyle(doctree.gray(235))
    ];
    $o.tableHeaderFill = doctree.gray(225);
    $o.codeFill = doctree.gray(245);
    $o.codeBorder = doctree.gray(170);
    $o.quoteRule = doctree.rgb(70, 110, 160);
    $o.title = "Pipeline notes";
    $o.bookmarkLevel = 2;
    return $o;
}

def src as string init fs.readString("notes.md");
def opts as doctree.PdfOptions init options();
def doc as pdf.Document init doctree.renderPdfDoc(myst.parse($src), $opts);
def foot as pdf.PageLabel init pdf.pageLabel();
$foot.right = "%page% / %pages%";
$foot.border = true;
fs.writeBytes("notes.pdf", pdf.render(pdf.setFooter($doc, $foot)));

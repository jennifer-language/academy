use io;
use math;
use strings;
import "markdown.j" as markdown;
import "doctree.j" as doctree;

def const PDF_MAX_DEPTH as int init 12;

# How deep blocks nest below n (an inline run counts once).
func depth(n as doctree.Node) {
    def d as int init 0;
    for (def c in doctree.children($n)) {
        $d = math.max($d, depth($c));
    }
    return $d + 1;
}

func toPdf(doc as doctree.Node, o as doctree.PdfOptions) {
    if (depth($doc) > PDF_MAX_DEPTH) {
        throw Error{kind: "limit", message: "too deep for the PDF layout"};
    }
    return doctree.renderPdf($doc, $o);
}

def doc as doctree.Node init markdown.parse(strings.replicate(">", 20) + " x\n");
try {
    io.printf("%d bytes\n", len(toPdf($doc, doctree.pdfDefaults())));
} catch (e) {
    io.printf("%s: %s (depth %d)\n", $e.kind, $e.message, depth($doc));
}

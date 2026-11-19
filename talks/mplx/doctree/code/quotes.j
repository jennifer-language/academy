use io;
use strings;
use time;
import "markdown.j" as markdown;
import "doctree.j" as doctree;

func ms(t0 as int) {
    return time.unixMillis(time.now()) - $t0;
}

def o as doctree.PdfOptions init doctree.pdfDefaults();
$o.quoteFill = doctree.gray(240);
for (def depth in [4, 8, 10, 12, 14]) {
    def md as string init strings.repeat(">", $depth) + " deep\n";
    def t0 as int init time.unixMillis(time.now());
    def out as bytes init doctree.renderPdf(markdown.parse($md), $o);
    io.printf("depth %d: %d ms, %d bytes\n", $depth, ms($t0), len($out));
}

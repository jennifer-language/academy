use io;
use strings;
use time;
import "markdown.j" as markdown;
import "doctree.j" as doctree;

def section as string init "## Section\n\nSome *text* with `code` and a [link](a.html).\n\n" +
    "- one\n- two\n\n| a | b |\n| --- | --- |\n| 1 | 2 |\n\n";
def md as string init strings.replicate($section, 400);

func ms(t0 as int) {
    return time.unixMillis(time.now()) - $t0;
}

def t0 as int init time.unixMillis(time.now());
def doc as doctree.Node init markdown.parse($md);
io.printf("parse %d KiB: %d ms\n", len($md) // 1024, ms($t0));
$t0 = time.unixMillis(time.now());
def html as string init doctree.render("html", $doc);
io.printf("html %d KiB: %d ms\n", len($html) // 1024, ms($t0));
$t0 = time.unixMillis(time.now());
def out as bytes init doctree.renderPdf($doc, doctree.pdfDefaults());
io.printf("pdf %d KiB: %d ms\n", len($out) // 1024, ms($t0));

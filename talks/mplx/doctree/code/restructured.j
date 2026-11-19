use io;
import "rst.j" as rst;
import "doctree.j" as doctree;

def src as string init "Setup\n=====\n\n.. _fig-pipe:\n\n" +
    ".. figure:: pipeline.png\n\n   The pipeline.\n\n" +
    ".. note:: See fig-pipe_ and `Setup`_; press :kbd:`Ctrl+C`.\n\n" +
    "Read :pep:`8`, then missing_.\n";

func dump(n as doctree.Node, pad as string) {
    def extra as string init $n.lang + $n.url;
    if ($n.kind == "text" or $n.kind == "codespan") {
        $extra = "\"" + $n.text + "\"";
    }
    io.printf("%s%s %v %s\n", $pad, $n.kind, $n.attrs, $extra);
    for (def c in doctree.children($n)) {
        dump($c, $pad + "  ");
    }
}

def doc as doctree.Node init rst.parse($src);
dump($doc, "");
io.printf("title: %s\n", rst.title($doc));
for (def d in rst.check($src)) {
    io.printf("%s line %d: %s\n", $d.severity, $d.line, $d.message);
}

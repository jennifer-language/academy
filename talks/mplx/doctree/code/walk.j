use io;
import "markdown.j" as markdown;
import "doctree.j" as doctree;

def src as string init "# Guide\n\nRead **this** and [that](https://x.org).\n\n" +
    "- one\n- two\n";
def doc as doctree.Node init markdown.parse($src);

func dump(n as doctree.Node, pad as string) {
    def t as string init "";
    if ($n.kind == "text") {
        $t = " \"" + $n.text + "\"";
    }
    io.printf("%s%s%s\n", $pad, $n.kind, $t);
    for (def c in doctree.children($n)) {
        dump($c, $pad + "  ");
    }
}

dump($doc, "");
io.printf("%s\n", doctree.text(doctree.get($doc, "list/item[2]")));
io.printf("%d\n", len(doctree.findAll($doc, "paragraph/link")));
io.printf("%d\n", len(doctree.findAll($doc, "link")));
io.printf("%v\n", doctree.has($doc, "*/strong"));

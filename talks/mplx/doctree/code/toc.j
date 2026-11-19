use io;
use strings;
import "markdown.j" as markdown;
import "doctree.j" as doctree;

func slug(s as string) {
    return strings.replace(strings.lower($s), " ", "-");
}

func entry(h as doctree.Node) {
    def a as doctree.Node init doctree.Node{
        kind: "link",
        url: "#" + $h.attrs["id"],
        children: [doctree.Node{kind: "text", text: doctree.text($h)}]
    };
    return doctree.Node{kind: "item", children: [$a]};
}

# Give every h2 an id; put a list of links to them after the h1.
func withToc(doc as doctree.Node) {
    def toc as doctree.Node init doctree.Node{kind: "list"};
    def body as list of doctree.Node init [];
    for (def n in doctree.children($doc)) {
        if ($n.kind == "heading" and $n.level == 2) {
            $n.attrs["id"] = slug(doctree.text($n));
            $toc.children[] = entry($n);
        }
        $body[] = $n;
    }
    def out as list of doctree.Node init [$body[0], $toc];
    for (def i in 1..len($body)) {
        $out[] = $body[$i];
    }
    return doctree.Node{kind: "document", children: $out};
}

def md as string init "# Guide\n\n## Install it\n\nText.\n\n## Run it\n";
def doc as doctree.Node init withToc(markdown.parse($md));
io.printf("%s\n", doctree.render("html", $doc));

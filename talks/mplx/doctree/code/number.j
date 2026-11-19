use io;
use lists;
use maps;
import "myst.j" as myst;
import "doctree.j" as doctree;

# Pass 1: every figure's "#id", in document order.
func figures(n as doctree.Node) {
    def ids as list of string init [];
    if ($n.kind == "figure") {
        $ids[] = "#" + doctree.attr($n, "id");
    }
    for (def c in doctree.children($n)) {
        $ids = lists.concat($ids, figures($c));
    }
    return $ids;
}

func txt(s as string) {
    return doctree.Node{kind: "text", text: $s};
}

# "Figure N. " for the figure fig.
func label(fig as doctree.Node, nums as map of string to int) {
    def no as int init $nums["#" + doctree.attr($fig, "id")];
    return txt("Figure {$no}. ");
}

# Pass 2: rebuild the tree, numbering captions and references.
func number(n as doctree.Node, nums as map of string to int) {
    def kids as list of doctree.Node init [];
    for (def c in doctree.children($n)) {
        if ($c.kind == "caption") {
            $c.children = lists.concat([label($n, $nums)], $c.children);
        }
        $kids[] = number($c, $nums);
    }
    $n.children = $kids;
    if ($n.kind == "link" and maps.has($nums, $n.url)) {
        $n.children = [txt("Figure {$nums[$n.url]}")];
    }
    return $n;
}

def src as string init '```{figure} a.png
:name: fig-a

Lexing.
```

```{figure} b.png
:name: fig-b

Parsing, after {numref}`fig-a`.
```
';
def doc as doctree.Node init myst.parse($src);
def nums as map of string to int init {};
for (def id in figures($doc)) {
    $nums[$id] = len($nums) + 1;
}
io.printf("%s\n", doctree.render("html", number($doc, $nums)));

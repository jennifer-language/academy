use io;
import "myst.j" as myst;
import "doctree.j" as doctree;

def src as string init '(setup)=
## Setup

```{figure} pipeline.png
:name: fig-pipe

The pipeline.
```

:::{note}
See {numref}`fig-pipe` and {ref}`setup`; press {kbd}`Ctrl+C`.
:::

Read {pep}`8`, then {foo}`bar`.
';

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

dump(myst.parse($src), "");
for (def d in myst.check($src)) {
    io.printf("%s line %d: %s\n", $d.severity, $d.line, $d.message);
}

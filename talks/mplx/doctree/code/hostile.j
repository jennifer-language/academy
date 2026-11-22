use io;
use strings;
import "markdown.j" as markdown;
import "myst.j" as myst;
import "rst.j" as rst;
import "doctree.j" as doctree;

func parse(reader as string, src as string) {
    match ($reader) {
        when "myst" { return myst.parse($src); }
        when "rst" { return rst.parse($src); }
    }
    return markdown.parse($src);
}

func attempt(reader as string, src as string) {
    try {
        def d as doctree.Node init parse($reader, $src);
        io.printf("%s: ok, %d nodes\n", $reader, len(doctree.findAll($d, "*")));
    } catch (e) {
        io.printf("%s: %s: %s\n", $reader, $e.kind, $e.message);
    }
}

def fences as string init "";
for (def i in 0..60) {
    $fences = $fences + strings.replicate(":", 70 - $i) + '{note}' + "\n";
}
attempt("markdown", strings.replicate(">", 150) + " deep\n");
attempt("myst", $fences + "deep\n");
attempt("rst", strings.replicate("* ", 120) + "deep\n");

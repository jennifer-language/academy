use io;
use strings;
import "markdown.j" as markdown;

for (def n in [30, 40]) {
    def md as string init strings.replicate("*a ", $n) + "x" + strings.replicate(" a*", $n);
    def html as string init markdown.toHtml($md);
    io.printf("%d levels: %d <em>\n", $n, strings.count($html, "<em>"));
}

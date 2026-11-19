use io;
import "markdown.j" as markdown;
import "myst.j" as myst;
import "rst.j" as rst;
import "doctree.j" as doctree;

def trees as list of doctree.Node init [
    markdown.parse("> [!WARNING]\n> Back up *first*.\n"),
    myst.parse('```{warning}' + "\nBack up *first*.\n```\n"),
    rst.parse(".. warning:: Back up *first*.\n")
];
for (def doc in $trees) {
    def n as doctree.Node init doctree.get($doc, "admonition");
    io.printf("%s %s: %s\n", doctree.typeOf($n), $n.lang, doctree.text($n));
}
io.printf("%s\n", doctree.render("html", $trees[2]));

# markdown-demo.j - one Markdown string to HTML
use io;
import "markdown.j" as markdown;

def md as string init "## Why?\n\nA **small** program, *my* rules.\n";
io.printf("%s\n", markdown.toHtml($md));

# "413 bytes that want to be a billion nodes": the alias bomb, all nine lines.
use io;
use yaml;

def doc as string init "a: &a [x, x, x, x, x, x, x, x, x, x]\n" +
    "b: &b [*a, *a, *a, *a, *a, *a, *a, *a, *a, *a]\n" +
    "c: &c [*b, *b, *b, *b, *b, *b, *b, *b, *b, *b]\n" +
    "d: &d [*c, *c, *c, *c, *c, *c, *c, *c, *c, *c]\n" +
    "e: &e [*d, *d, *d, *d, *d, *d, *d, *d, *d, *d]\n" +
    "f: &f [*e, *e, *e, *e, *e, *e, *e, *e, *e, *e]\n" +
    "g: &g [*f, *f, *f, *f, *f, *f, *f, *f, *f, *f]\n" +
    "h: &h [*g, *g, *g, *g, *g, *g, *g, *g, *g, *g]\n" +
    "i: &i [*h, *h, *h, *h, *h, *h, *h, *h, *h, *h]\n";
try {
    yaml.decode($doc);
} catch (e) {
    io.printf("%d bytes: %s\n  %s\n", len($doc), $e.kind, $e.message);
}

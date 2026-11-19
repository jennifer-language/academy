use binary;
use fs;
use io;
import "font.j" as font;
import "pdf.j" as pdf;

func attempt(what as string, b as bytes) {
    try {
        def lf as pdf.LoadedFont init pdf.loadFont("F", $b);
        io.printf("%s: %d glyphs\n", $what, font.numGlyphs($lf.f));
    } catch (e) {
        io.printf("%s: %s: %s\n", $what, $e.kind, $e.message);
    }
}

def ttf as bytes init fs.readBytes("/usr/share/fonts/TTF/DejaVuSans.ttf");
attempt("truncated", binary.slice($ttf, 0, 4000));
attempt("otf", fs.readBytes("/usr/share/fonts/cantarell/Cantarell-VF.otf"));

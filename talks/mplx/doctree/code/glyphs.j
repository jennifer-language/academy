use convert;
use fs;
use strings;
import "font.j" as font;

# One SVG path per glyph; kerning from the legacy kern table if asked.
func word(f as font.Font, s as string, y as int, kerned as bool) {
    def out as string init "";
    def x as int init 0;
    def prev as int init 0;
    for (def ch in strings.chars($s)) {
        def cp as int init convert.toCodepoint($ch);
        if ($kerned and $prev != 0) {
            $x = $x + font.kern($f, $prev, $cp);
        }
        def d as string init font.glyphPath($f, $cp);
        $out = $out + "<path transform=\"translate({$x},{$y}) scale(1,-1)\"" +
            " d=\"{$d}\"/>\n";
        $x = $x + font.advance($f, $cp);
        $prev = $cp;
    }
    return $out;
}

def f as font.Font init font.open("/usr/share/fonts/TTF/DejaVuSans.ttf");
def svg as string init "<svg xmlns=\"http://www.w3.org/2000/svg\"" +
    " viewBox=\"-100 -100 8800 3700\">\n" + word($f, "AVATAR", 1600, false) +
    word($f, "AVATAR", 3400, true) + "</svg>\n";
fs.writeString("kern.svg", $svg);

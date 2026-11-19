use io;
import "font.j" as font;

def f as font.Font init font.open("/usr/share/fonts/TTF/DejaVuSans.ttf");
def name as string init font.name($f);
def glyphs as int init font.numGlyphs($f);
def upem as int init font.unitsPerEm($f);
io.printf("{$name}: {$glyphs} glyphs, {$upem} units per em\n");
io.printf("ascender %d, descender %d, line gap %d\n",
    font.ascender($f), font.descender($f), font.lineGap($f));
io.printf("advance A %d, V %d; kern A,V %d\n",
    font.advance($f, 65), font.advance($f, 86), font.kern($f, 65, 86));
io.printf("glyph ids of U+006E, U+0144, U+4E2D: %v\n",
    font.glyphIds($f, [0x6E, 0x144, 0x4E2D]));
io.printf("L: %s\n", font.glyphPath($f, 76));

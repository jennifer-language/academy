use fs;
use io;
import "pdf.j" as pdf;

# DejaVu Sans: Bitstream Vera licence, changes in the public domain.
def path as string init "/usr/share/fonts/TTF/DejaVuSans.ttf";
def body as pdf.LoadedFont init pdf.loadFont("Body", fs.readBytes($path));
# "Gdansk, Delphi, Kyiv" in Polish, Greek and Russian, as escapes
def s as string init "Gda\u0144sk, \u0394\u03b5\u03bb\u03c6\u03bf\u03af, " +
    "\u041a\u0438\u0435\u0432";
def p as pdf.Page init pdf.textUnicode(pdf.page(300, 60), 12, 24, $body, 16, $s);
def doc as pdf.Document init pdf.addFont(pdf.document(), $body);
def out as bytes init pdf.render(pdf.addPage($doc, $p));
fs.writeBytes("unicode.pdf", $out);
def w as float init pdf.measureTextUnicode($body, 16, $s);
io.printf("%d bytes, %v pt wide\n", len($out), $w);

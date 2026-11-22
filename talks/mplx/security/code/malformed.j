# "Malformed bytes: the module's kind, not runtime": a real JPEG cut three
# bytes into its SOF0 frame header, handed to pdf.loadImage.
import "pdf.j" as pdf;
use io;
use binary;
use encoding;
use images;

def jpeg as bytes init images.encode("jpeg", images.create(64, 64));
def sof as bytes init encoding.fromText("hex", "ffc0");   # SOF0
def at as int init binary.indexOf($jpeg, $sof);
def cut as bytes init $jpeg[..$at + 3];   # mid header
try {
    pdf.loadImage("Logo", $cut);
} catch (e) {
    io.printf("%s\n%s\n", $e.kind, $e.message);
}

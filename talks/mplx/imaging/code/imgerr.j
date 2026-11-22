use io;
use images;
use encoding;

def junk as bytes init encoding.encode("utf-8", "not an image");
try {
    images.decode($junk);
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
def img as images.Image init images.create(100, 100);
try {
    images.crop($img, 50, 50, 100, 100);
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
try {
    images.rotate($img, 45);
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}

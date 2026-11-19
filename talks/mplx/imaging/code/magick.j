use io;
import "@deckyard/magick/" as magick;

def c as magick.Config init magick.config();
def info as magick.Info init magick.identify($c, "phone.jpg");
io.printf("%dx%d %s\n", $info.width, $info.height, $info.orientation);

def img as magick.Image init magick.open($c, "phone.jpg");
$img = magick.thumbnail(magick.autoOrient($img), 640, 640);
$img = magick.annotate($img, "Summer 2026", "SouthEast", 12, 8, 28,
    "white");
magick.write($c, magick.quality($img, 80), "phone.webp");
$info = magick.identify($c, "phone.webp");
io.printf("%s %dx%d\n", $info.format, $info.width, $info.height);

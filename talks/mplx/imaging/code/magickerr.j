use io;
use images;
use fs;
import "@deckyard/magick/" as magick;

io.printf("%v\n", images.info(fs.readBytes("phone.jpg")));
def c as magick.Config init magick.config();
try {
    magick.open($c, "logo.svg");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
try {
    magick.identify($c, "bomb.png");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}

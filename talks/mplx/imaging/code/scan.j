use os;
use fs;
use images;
import "@deckyard/escl/" as escl;
import "@deckyard/escl/scanpdf.j" as scanpdf;

def st as escl.Settings init escl.settings(); # platen, JPEG
$st.colorMode = "Grayscale8";
$st.resolution = 150;
def s as escl.Scanner init escl.scanner(os.ARGS[1]); # host:port
def pages as list of escl.Page init escl.scan($s, $st);
for (def i in 0..len($pages)) {
    def img as images.Image init images.decode($pages[$i].data);
    def bw as images.Image init images.threshold($img, 160);
    $pages[$i].data = images.encode("png", $bw);
    $pages[$i].contentType = "image/png";
}
fs.writeBytes("letter.pdf", scanpdf.build($pages, $st.resolution));

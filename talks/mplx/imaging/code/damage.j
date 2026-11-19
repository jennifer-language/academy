use fs;
use images;

def red as images.Color init images.rgb(220, 40, 40);
for (def ec in ["L", "M", "Q", "H"]) {
    def m as images.Image init images.decode(fs.readBytes("qr-{$ec}.png"));
    def q as int init images.width($m) // 8;
    def hit as images.Image init images.fill($m, 3 * $q, 3 * $q, 2 * $q,
        2 * $q, $red); # a sticker in the middle
    fs.writeBytes("hit-{$ec}.png", images.encode("png", $hit));
}

use io;
use fs;
import "barcode.j" as barcode;

def opts as barcode.Options init barcode.defaults();
$opts.scale = 4;
for (def ec in ["L", "M", "Q", "H"]) {
    $opts.ecLevel = $ec;
    def qr as barcode.Symbol init barcode.encode("qr",
        "https://academy.jennifer-lang.dev/", $opts);
    def png as bytes init barcode.png($qr, $opts);
    fs.writeBytes("qr-{$ec}.png", $png);
    io.printf("%s: %d modules, %d bytes\n", $ec, $qr.size, len($png));
}

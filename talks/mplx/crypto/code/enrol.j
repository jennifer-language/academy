use io;
use fs;
import "totp.j" as totp;
import "barcode.j" as barcode;

def o as totp.Options;
def secret as string init totp.generateSecret();
def link as string init totp.uri("Shelf", "ada@example.org", $secret, $o);
io.printf("%s\n", $link);

def bo as barcode.Options init barcode.defaults();
$bo.scale = 4;
def qr as barcode.Symbol init barcode.encode("qr", $link, $bo);
fs.writeBytes("enrol.png", barcode.png($qr, $bo));
io.printf("QR %dx%d modules\n", $qr.size, $qr.size);

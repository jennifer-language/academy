use io;
use convert;
use encoding;
use crypto;
import "@deckyard/sealbox/" as sealbox;

def key as bytes init sealbox.newKey();
def plain as bytes init convert.bytesFromString("utf-8", "db password: PLACEHOLDER");
def id as bytes init convert.bytesFromString("utf-8", "row 17");
def box as bytes init sealbox.sealWith($plain, $key, $id);
io.printf("box %d bytes for %d\n", len($box), len($plain));
io.printf("%s\n", convert.stringFromBytes("utf-8", sealbox.openWith($box, $key, $id)));
try {
    def other as bytes init convert.bytesFromString("utf-8", "row 18");
    sealbox.openWith($box, $key, $other);
} catch (e) {
    io.printf("%s | %s\n", $e.kind, $e.message);
}
def fkey as string init encoding.toText("base64-url", crypto.randBytes(32));
def tok as string init sealbox.fernetEncrypt($plain, $fkey);
io.printf("fernet %s...\n", $tok[0..24]);
io.printf("%d bytes back\n", len(sealbox.fernetDecrypt($tok, $fkey, 300)));

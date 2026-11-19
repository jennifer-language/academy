use convert;
use io;
use os;
import "@deckyard/koofr/" as koofr;

def c as koofr.Client init koofr.client(os.getEnv("KOOFR_URL"));
$c = koofr.withAppPassword($c, os.getEnv("KOOFR_EMAIL"),
    os.getEnv("KOOFR_PASSWORD"));
def m as koofr.Mount init koofr.primaryMount($c);
io.printf("mount %s (%s), id %s\n", $m.name, $m.origin, $m.id);
koofr.mkdirAll($c, $m.id, "/Backups/2026/11");
def opts as koofr.PutOptions;                     # zero value: refuse
def data as bytes init convert.bytesFromString("utf-8", "buy milk\n");
def f as koofr.File init koofr.put($c, $m.id,
    "/Backups/2026/11/notes.txt", $data, $opts);
io.printf("put %s, %d bytes\n", $f.path, $f.size);
def l as koofr.Link init koofr.createLink($c, $m.id, $f.path);
io.printf("link %s\n", $l.shortUrl);
try {
    koofr.put($c, $m.id, $f.path, $data, $opts);   # exists already
} catch (e) {
    if ($e.kind != "koofr") {
        throw $e;
    }
    def k as koofr.KoofrError init $e;
    io.printf("%d %s\n", $k.status, $k.code);
}

use convert;
use io;
use os;
import "webdav.j" as webdav;

func save(c as webdav.Client, p as string, s as string, t as string) {
    def o as webdav.PutOptions;
    $o.ifMatch = $t;                      # only if nobody changed it
    webdav.putWith($c, $p, convert.bytesFromString("utf-8", $s), $o);
}

def c as webdav.Client init webdav.connect(os.getEnv("DAV_URL"));
$c = webdav.withBasicAuth($c, os.getEnv("DAV_USER"),
    os.getEnv("DAV_PASSWORD"));
def p as string init "/Backups/2026/11/notes.txt";
def mine as string init webdav.stat($c, $p).etag;
io.printf("read     %s\n", $mine);
save($c, $p, "buy milk and bread\n", $mine);      # another writer
io.printf("changed  %s\n", webdav.stat($c, $p).etag);
try {
    save($c, $p, "buy milk and eggs\n", $mine);   # my stale copy
} catch (e) {
    if ($e.kind != "webdav") {
        throw $e;
    }
    def w as webdav.WebdavError init $e;
    io.printf("refused  %d %s %s\n", $w.status, $w.method, $w.path);
}

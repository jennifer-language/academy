use convert;
use io;
use os;
import "webdav.j" as webdav;

def const FILE as string init "/Backups/2026/11/notes.txt";

func attempt(c as webdav.Client, what as string) {
    def data as bytes init convert.bytesFromString("utf-8", "v2\n");
    def o as webdav.PutOptions;
    try {
        match ($what) {
            when "stale" {
                $o.ifMatch = "\"0bad\"";
                webdav.putWith($c, FILE, $data, $o);
            }
            when "new" {
                $o.onlyIfNew = true;
                webdav.putWith($c, FILE, $data, $o);
            }
            when "missing" { webdav.get($c, "/nope.txt", 0); }
            when "parent" { webdav.put($c, "/no/dir/a.txt", $data); }
            when "mkdir" { webdav.mkdir($c, "/Backups"); }
            else { webdav.readDir($c, "/"); }
        }
        io.printf("%s: ok\n", $what);
    } catch (e) {
        if ($e.kind != "webdav") {
            throw $e;
        }
        def w as webdav.WebdavError init $e;
        io.printf("%s: %d %s %s\n", $what, $w.status, $w.method, $w.path);
    }
}

def c as webdav.Client init webdav.connect(os.getEnv("DAV_URL"));
$c = webdav.withBasicAuth($c, os.getEnv("DAV_USER"),
    os.getEnv("DAV_PASSWORD"));
for (def w in ["stale", "new", "missing", "parent", "mkdir"]) {
    attempt($c, $w);
}
attempt(webdav.withBasicAuth($c, "alice", "wrong"), "auth");

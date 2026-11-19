use convert;
use io;
use os;
import "webdav.j" as webdav;

def c as webdav.Client init webdav.connect(os.getEnv("DAV_URL"));
$c = webdav.withBasicAuth($c, os.getEnv("DAV_USER"),
    os.getEnv("DAV_PASSWORD"));
webdav.mkdirAll($c, "/Backups/2026/11");                 # MKCOL x3
def text as bytes init convert.bytesFromString("utf-8", "buy milk\n");
webdav.put($c, "/Backups/2026/11/notes.txt", $text);     # PUT
webdav.copy($c, "/Backups/2026/11/notes.txt", "/Backups/copy.txt",
    false);                                              # COPY
webdav.move($c, "/Backups/copy.txt", "/Backups/old.txt", false);
for (def r in webdav.readDir($c, "/Backups")) {          # PROPFIND
    io.printf("%s %t %d %s\n", $r.path, $r.isDir, $r.size, $r.etag);
}
def back as bytes init webdav.get($c, "/Backups/2026/11/notes.txt", 0);
io.printf("get: %s", convert.stringFromBytes("utf-8", $back));

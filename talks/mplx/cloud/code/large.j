use fs;
use io;
use os;
import "webdav.j" as webdav;
import "@deckyard/seafile/" as seafile;

def big as bytes init fs.readBytes(os.ARGS[1]);       # 12 MiB
def d as webdav.Client init webdav.connect(os.getEnv("DAV_URL"));
$d = webdav.withBasicAuth($d, os.getEnv("DAV_USER"),
    os.getEnv("DAV_PASSWORD"));
webdav.put($d, "/big.bin", $big);
try {
    webdav.get($d, "/big.bin", 1024 * 1024);          # at most 1 MiB
} catch (e) {
    io.printf("[%s] %s\n", $e.kind, $e.message);
}
def s as seafile.Client init seafile.client(os.getEnv("SEAFILE_URL"));
$s = seafile.withToken($s, seafile.login($s, os.getEnv("SEAFILE_USER"),
    os.getEnv("SEAFILE_PASSWORD"), ""));
def lib as seafile.Library;
for (def l in seafile.libraries($s, "mine")) {
    if ($l.name == "Backups") {
        $lib = $l;
    }
}
def e as seafile.Entry init seafile.putResumable($s, $lib.id,
    "/big.bin", $big, 4 * 1024 * 1024, true, false);  # 3 chunks
io.printf("%s: %d bytes in %s\n", $e.path, $e.size, $lib.name);

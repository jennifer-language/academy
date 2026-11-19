use io;
use fs;
use os;
use json;
use convert;
import "jwt.j" as jwt;

# a key file must be owner-only, like ssh's private keys
func keyFile(path as string) {
    if (fs.stat($path).mode & 0o077 != 0) {
        throw Error{kind: "config", message: $path + " is readable by others"};
    }
    return fs.readString($path);
}

def dir as string init os.getEnv("SHELF_KEY_DIR");
def keys as map of string to string init {"2026-10": keyFile($dir + "/jwt-2026-10")};
try {
    $keys["2026-11"] = keyFile($dir + "/jwt-2026-11");
} catch (e) {
    io.printf("%s | %s\n", $e.kind, $e.message);
}
fs.chmod($dir + "/jwt-2026-11", 0o600);
$keys["2026-11"] = keyFile($dir + "/jwt-2026-11");

def c as json.Value init json.decode('{"sub":"ada","exp":9999999999}');
def old as string init jwt.signWithKid("HS256", $c,
    convert.bytesFromString("utf-8", $keys["2026-10"]), "2026-10");
def fresh as string init jwt.signWithKid("HS256", $c,
    convert.bytesFromString("utf-8", $keys["2026-11"]), "2026-11");
for (def t in [$old, $fresh]) {
    def back as json.Value init jwt.verifyWithKeys("HS256", $t, $keys);
    io.printf("kid %s: sub=%s\n", json.asString(jwt.header($t), "/kid"),
        json.asString($back, "/sub"));
}

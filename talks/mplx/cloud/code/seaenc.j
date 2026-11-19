use convert;
use io;
use os;
import "@deckyard/seafile/" as seafile;

func unlock(c as seafile.Client, id as string, password as string) {
    try {
        seafile.decrypt($c, $id, $password);
        io.printf("decrypt: ok\n");
    } catch (e) {
        if ($e.kind != "seafile") {
            throw $e;
        }
        def s as seafile.SeafileError init $e;
        io.printf("decrypt: %d %s\n", $s.status, $s.message);
    }
}

def c as seafile.Client init seafile.client(os.getEnv("SEAFILE_URL"));
$c = seafile.withToken($c, seafile.login($c, os.getEnv("SEAFILE_USER"),
    os.getEnv("SEAFILE_PASSWORD"), ""));
def secret as string init os.getEnv("VAULT_PASSWORD");
def v as seafile.Library init seafile.createLibrary($c, "Vault", $secret);
io.printf("%s encrypted=%t\n", $v.name, $v.encrypted);
unlock($c, $v.id, "not-the-password");
unlock($c, $v.id, $secret);
def pin as bytes init convert.bytesFromString("utf-8", "pin 0000\n");
seafile.put($c, $v.id, "/secret.txt", $pin, true);
def back as bytes init seafile.get($c, $v.id, "/secret.txt", 0);
io.printf("get: %s", convert.stringFromBytes("utf-8", $back));

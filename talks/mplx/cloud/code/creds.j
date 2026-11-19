use convert;
use io;
use os;
import "@deckyard/koofr/" as koofr;
import "@deckyard/seafile/" as seafile;

def k as koofr.Client init koofr.client("http://files.example.com");
$k = koofr.withAppPassword($k, "me@example.com", "example-app-password");
try {
    koofr.user($k);                       # throws before it connects
} catch (e) {
    io.printf("[%s] %s\n", $e.kind, $e.message);
}
def s as seafile.Client init seafile.client(os.getEnv("SEAFILE_URL"));
def me as seafile.Client init seafile.withToken($s, seafile.login($s,
    os.getEnv("SEAFILE_USER"), os.getEnv("SEAFILE_PASSWORD"), ""));
def lib as seafile.Library;
for (def l in seafile.libraries($me, "mine")) {
    if ($l.name == "Backups") {
        $lib = $l;
    }
}
def t as seafile.ApiToken init seafile.createApiToken($me, $lib.id,
    "nightly", "r");                      # read-only, one library
def ro as seafile.Client init seafile.withRepoToken($s, $lib.id,
    $t.token);
io.printf("token for %s, permission %s\n",
    seafile.tokenLibrary($ro).name, $t.permission);
try {
    seafile.put($ro, $lib.id, "/x.txt",
        convert.bytesFromString("utf-8", "x"), true);
} catch (e) {
    io.printf("[%s] %s\n", $e.kind, $e.message);
}

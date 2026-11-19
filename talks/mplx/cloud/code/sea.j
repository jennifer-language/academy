use convert;
use os;
use io;
import "@deckyard/seafile/" as seafile;

def c as seafile.Client init seafile.client(os.getEnv("SEAFILE_URL"));
def token as string init seafile.login($c, os.getEnv("SEAFILE_USER"),
    os.getEnv("SEAFILE_PASSWORD"), "");          # "" = no 2FA code
$c = seafile.withRetries(seafile.withToken($c, $token), 3);
def data as bytes init convert.bytesFromString("utf-8", "buy milk\n");
def o as seafile.ShareLinkOptions;
$o.expireDays = 7;
def l as seafile.Library init seafile.createLibrary($c, "Backups", "");
seafile.mkdir($c, $l.id, "/2026/11", true);      # with parents
def e as seafile.Entry init seafile.put($c, $l.id,
    "/2026/11/notes.txt", $data, true);          # replace if there
def s as seafile.ShareLink init seafile.createShareLink($c, $l.id,
    $e.path, $o);
def u as seafile.UploadLink init seafile.createUploadLink($c, $l.id,
    "/2026", "", 0);                             # open, no expiry
io.printf("share  %s\nupload %s\n", $s.link, $u.link);

use io;
use crypto;
use strings;
use time;
import "password.j" as password;

def t0 as int init time.unixMillis(time.now());
def stored as string init crypto.hashPassword("argon2id", "correct horse battery");
def ms as int init time.unixMillis(time.now()) - $t0;
io.printf("%s (%d ms)\n", $stored, $ms);
io.printf("%t\n", crypto.verifyPassword("Correct horse battery", $stored));

def pw as string init "correct horse battery";
def old as string init crypto.hashPassword("bcrypt", $pw);
# on login: an old bcrypt hash that verified is replaced
if (crypto.verifyPassword($pw, $old) and strings.startsWith($old, "$2")) {
    $old = crypto.hashPassword("argon2id", $pw);
}
io.printf("now %s...\n", $old[0..30]);
def policy as password.Schema init password.withLength(password.schema(), 12, 64);
def r as password.Report init password.validate($policy, "hunter2");
io.printf("%t %s\n", $r.valid, strings.join($r.reasons, "; "));

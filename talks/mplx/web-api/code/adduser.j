# adduser.j - create an API user; the password is read from standard input
# usage: echo PASSWORD | jennifer run adduser.j NAME "orders:read orders:write"
# pragma-jennifer-capability: sql

use sql;
use os;
use io;
use strings;
import "password.j" as password;
import "./src/store.j" as store;

if (len(os.ARGS) != 3) {
    io.eprintf("usage: adduser.j NAME SCOPES\n");
    exit 2;
}
def pw as string init strings.trim(io.readLine());
# 12 to 128 characters, at least one lowercase, uppercase and digit
def policy as password.Schema init password.withMinimums(
    password.withLength(password.schema(), 12, 128), 1, 1, 1, 0);
def report as password.Report init password.validate($policy, $pw);
if (not $report.valid) {
    io.eprintf("adduser: %s\n", strings.join($report.reasons, "; "));
    exit 1;
}
def conn as sql.Connection init sql.open("postgres", os.getEnv("SHOP_DB_DSN"));
defer sql.close($conn);
def id as int init store.addUser($conn, os.ARGS[1], $pw, os.ARGS[2]);
io.printf("user %d: %s (%s)\n", $id, os.ARGS[1], os.ARGS[2]);

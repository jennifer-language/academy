# Create a member: the name is the argument, the password comes from
# standard input, so it stays out of the shell history and the process list.
# Run: echo 'correct horse battery' | jennifer run addmember.j ada
use fs;
use io;
use os;
use sql;
use strings;
import "./src/store.j" as store;

if (len(os.ARGS) != 2 or os.ARGS[1] == "") {
    io.eprintf("usage: jennifer run addmember.j NAME < password\n");
    exit 2;
}
def dsn as string init os.getEnv("SHELF_DB_DSN");
if (os.getEnv("SHELF_DB_DSN_FILE") != "") {
    $dsn = strings.trim(fs.readString(os.getEnv("SHELF_DB_DSN_FILE")));
}
def password as string init strings.trim(io.readLine());
if (len($password) < 12) {
    io.eprintf("addmember: the password needs 12 characters or more\n");
    exit 2;
}
def db as sql.Connection init store.open($dsn);
def id as int init store.addMember($db, os.ARGS[1], $password);
io.printf("member %d: %s\n", $id, os.ARGS[1]);

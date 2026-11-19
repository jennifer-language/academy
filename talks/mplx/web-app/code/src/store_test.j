# Tests for store.j against a throwaway MariaDB database. jennifer test
# splices store.j in front of this file, so open, addBook and the rest are
# called by their bare names.
# Run: SHELF_TEST_DSN='root:test@tcp(127.0.0.1:3399)/' jennifer test src/store_test.j
# Without SHELF_TEST_DSN every test returns at once (a skip).
use os;
use testing;
use uuid;

def struct Fixture {
    admin as sql.Connection,
    conn as sql.Connection,
    name as string
};

# a database of its own, with a random name, migrated by open()
func fresh() {
    def server as string init os.getEnv("SHELF_TEST_DSN");
    def name as string init "shelftest_" + uuid.v4()[..8];
    def admin as sql.Connection init sql.open("mariadb", $server);
    sql.exec($admin, "CREATE DATABASE " + $name);
    def conn as sql.Connection init open($server + $name); # migrated
    return Fixture{admin: $admin, conn: $conn, name: $name};
}

func dispose(f as Fixture) {
    sql.close($f.conn);
    sql.exec($f.admin, "DROP DATABASE " + $f.name);
    sql.close($f.admin);
}

func testBooksListUnreadFirst() {
    if (os.getEnv("SHELF_TEST_DSN") == "") { return; }   # skip
    def f as Fixture init fresh();
    defer dispose($f);
    def ada as int init addMember($f.conn, "ada", "correct horse battery");
    def first as int init addBook($f.conn, $ada, "Kindred", "O. E. Butler");
    addBook($f.conn, $ada, "Solaris", "Stanislaw Lem");
    testing.assertTrue(markDone($f.conn, $first));
    testing.assertFalse(markDone($f.conn, $first));     # already read
    testing.assertEqual(books($f.conn)[0].title, "Solaris");
}

func testLoginChecksThePassword() {
    if (os.getEnv("SHELF_TEST_DSN") == "") { return; }   # skip
    def f as Fixture init fresh();
    defer dispose($f);
    def ada as int init addMember($f.conn, "ada", "correct horse battery");
    testing.assertEqual(login($f.conn, "ada", "correct horse battery"), $ada);
    testing.assertEqual(login($f.conn, "ada", "wrong"), 0);
    testing.assertEqual(login($f.conn, "nobody", "correct horse battery"), 0);
}

func testNamesAreUnique() {
    if (os.getEnv("SHELF_TEST_DSN") == "") { return; }   # skip
    def f as Fixture init fresh();
    defer dispose($f);
    addMember($f.conn, "ada", "correct horse battery");
    def kind as string init "";
    try {
        addMember($f.conn, "ada", "another password");
    } catch (e) {
        $kind = $e.kind;
    }
    testing.assertTrue($kind != "");      # the UNIQUE key refused it
}

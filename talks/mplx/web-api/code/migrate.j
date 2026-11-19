# migrate.j - bring the schema up to date; run once per deploy, before the app
# usage: jennifer run migrate.j [--status]
# pragma-jennifer-capability: sql

use sql;
use os;
use io;
import "sqlmigrate.j" as mig;
import "./src/store.j" as store;

def conn as sql.Connection init sql.open("postgres", os.getEnv("SHOP_DB_DSN"));
defer sql.close($conn);

if (os.hasFlag("--status")) {
    for (def m in mig.migrationStatus($conn, store.MIGRATIONS)) {
        def mark as string init "pending";
        if ($m.applied) {
            $mark = "applied";
        }
        io.printf("%s %s %s\n", $m.version, $mark, $m.description);
    }
    exit 0;
}

# sqlmigrate 0.26.0 takes no lock: hold one ourselves, so two deploys that
# start together run each migration once. The lock lives as long as `lock`.
def lock as sql.Tx init sql.begin($conn);
defer sql.rollback($lock);
sql.closeRows(sql.query($lock,
    "SELECT pg_advisory_xact_lock(hashtext('shop.migrate'))"));
io.printf("lock held, migrating\n");
def n as int init mig.migrate($conn, store.MIGRATIONS);
io.printf("applied %d migration(s)\n", $n);

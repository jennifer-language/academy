use io;
use strings;
import "@deckyard/influxdb/" as influxdb;

def db as influxdb.Client init influxdb.clientWith("http://127.0.0.1:8086",
    "shop", "demo", "demo-token-not-secret");
def r as influxdb.Result init influxdb.query($db,
    'SELECT count("duration_ms") FROM "shop_job" WHERE time > now() - 1h GROUP BY "queue"');
for (def s in $r.series) {
    io.printf("%s %s %s\n", $s.name, $s.tags["queue"], strings.join($s.values[0], " "));
}
def c as influxdb.Result init influxdb.query($db, "SHOW SERIES CARDINALITY");
io.printf("%v\n", $c);

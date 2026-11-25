use io;
use time;
import "@deckyard/influxdb/" as influxdb;

func main() {
    def db as influxdb.Client init influxdb.client2("http://127.0.0.1:8086", "demo",
        "shop", "demo-token-not-secret");
    def now as time.Time init time.now();
    def right as influxdb.Point init influxdb.field(influxdb.point("ts_probe"), "v", 1.0);
    $right = influxdb.atTime($right, $now);
    def wrong as influxdb.Point init influxdb.field(influxdb.point("ts_probe"), "v", 2.0);
    $wrong = influxdb.at($wrong, time.unix($now));     # seconds, not ns
    io.printf("%s\n%s\n", influxdb.line($right), influxdb.line($wrong));
    influxdb.write($db, [$right, $wrong]);
    def q as influxdb.Client init influxdb.clientWith("http://127.0.0.1:8086", "shop",
        "demo", "demo-token-not-secret");
    def r as influxdb.Result init influxdb.query($q, 'SELECT "v" FROM "ts_probe"');
    for (def row in $r.series[0].values) {
        io.printf("%s %s\n", $row[0], $row[1]);
    }
}

main();

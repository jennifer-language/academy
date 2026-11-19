use io;
use strings;
import "csv.j" as csv;
import "@jennifer/influxdb/" as influxdb;

func main() {
    def db as influxdb.Client init influxdb.client2("http://127.0.0.1:8086", "demo",
        "shop", "demo-token-not-secret");
    def ok as influxdb.Point init influxdb.field(influxdb.point("partial_probe"), "v", 1.0);
    def bad as influxdb.Point init influxdb.intField(influxdb.point("shop_job"), "duration_ms", 1);
    try {
        influxdb.write($db, [$ok, $bad]);
    } catch (e) {
        io.printf("%s\n", $e.message);
    }
    def body as string init influxdb.queryFlux($db,
        'from(bucket: "shop") |> range(start: -1h) |> filter(fn: (r) => r._measurement == "partial_probe") |> count()');
    io.printf("%v\n", csv.parse(strings.trim($body)));
}

main();

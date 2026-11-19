use io;
use strings;
import "csv.j" as csv;
import "@jennifer/influxdb/" as influxdb;

def const URL as string init "http://127.0.0.1:8086";

func cardinality(db as influxdb.Client, m as string) {
    def body as string init influxdb.queryFlux($db, 'import "influxdata/influxdb"
influxdb.cardinality(bucket: "shop", start: -1h,
  predicate: (r) => r._measurement == "' + $m + '")');
    return csv.toRecords(csv.parse(strings.trim($body)))[0]["_value"];
}

func main() {
    def db as influxdb.Client init influxdb.client2(URL, "demo", "shop",
        "demo-token-not-secret");
    def batch as list of influxdb.Point init [];
    for (def i in 0..2000) {
        def p as influxdb.Point init influxdb.point("shop_job_by_id");
        $p = influxdb.tag($p, "job", "j{100000 + $i}");    # an id: wrong
        $batch[] = influxdb.field($p, "duration_ms", 50.0);
    }
    influxdb.write($db, $batch);
    for (def m in ["shop_job", "shop_job_by_id"]) {
        io.printf("%s|pad=16 %s series\n", $m, cardinality($db, $m));
    }
}

main();

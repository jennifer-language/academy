use io;
use convert;
use strings;
import "csv.j" as csv;
import "@jennifer/influxdb/" as influxdb;

def const URL as string init "http://127.0.0.1:8086";

func main() {
    def db as influxdb.Client init influxdb.client2(URL, "demo", "shop",
        "demo-token-not-secret");
    def body as string init influxdb.queryFlux($db, 'from(bucket: "shop")
  |> range(start: -15m)
  |> filter(fn: (r) => r._field == "duration_ms")
  |> group(columns: ["queue"])
  |> quantile(q: 0.95)');
    for (def row in csv.toRecords(csv.parse(strings.trim($body)))) {
        io.printf("%s|pad=8 %f|prec=1 ms\n", $row["queue"],
            convert.toFloat($row["_value"]));
    }
}

main();

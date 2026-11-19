use io;
import "@jennifer/influxdb/" as influxdb;

def const URL as string init "http://127.0.0.1:8086";
def const TOKEN as string init "demo-token-not-secret";

func show(e as influxdb.InfluxdbError) {
    io.printf("[%d %s] %s\n", $e.status, $e.code, $e.message);
}

func attempt(db as influxdb.Client, p as influxdb.Point) {
    try {
        influxdb.write($db, [$p]);
        io.printf("ok\n");
    } catch (e) {
        if ($e.kind != "influxdb") {
            io.printf("[%s] %s\n", $e.kind, $e.message);
            return null;
        }
        def ie as influxdb.InfluxdbError init $e;
        show($ie);
    }
    return null;
}

func main() {
    def good as influxdb.Client init influxdb.client2(URL, "demo", "shop", TOKEN);
    def p as influxdb.Point init influxdb.field(influxdb.point("shop_job"),
        "duration_ms", 12.5);
    attempt(influxdb.client2(URL, "demo", "shop", "wrong-token-123"), $p);
    attempt(influxdb.client2(URL, "demo", "shpo", TOKEN), $p);
    attempt($good, influxdb.intField(influxdb.point("shop_job"), "duration_ms", 12));
    attempt($good, influxdb.point("shop_job"));
    def nl as influxdb.Point init influxdb.tag(influxdb.point("shop_job"), "queue", "a\nb");
    attempt($good, influxdb.field($nl, "x", 1.0));
    attempt(influxdb.client2("http://127.0.0.1:8099", "demo", "shop", TOKEN), $p);
}

main();

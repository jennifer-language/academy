use io;
use time;
import "@deckyard/influxdb/" as influxdb;

def p as influxdb.Point init influxdb.point("shop_job");
$p = influxdb.tag($p, "queue", "orders");
$p = influxdb.field($p, "duration_ms", 53.2);
$p = influxdb.intField($p, "items", 3);
io.printf("%s\n", influxdb.line($p));
io.printf("%s\n", influxdb.line(influxdb.atTime($p, time.now())));
$p = influxdb.stringField($p, "note", "card");
$p = influxdb.boolField($p, "ok", true);
io.printf("%s\n", influxdb.line($p));

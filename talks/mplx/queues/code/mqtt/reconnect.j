use io;
use time;
use encoding;
import "mqtt.j" as mqtt;
import "transport.j" as transport;

# reconnect retries with a growing pause; anything but a lost link is rethrown.
func reconnect(c as mqtt.Client) {
    def pause as int init 250;
    while (true) {
        try { return mqtt.reconnect($c); } catch (e) {
            if (not ($e.kind == "net" or $e.kind == "closed"
                or $e.kind == "timeout")) { throw $e; }
            time.sleep(time.fromMilliseconds($pause));
            if ($pause < 4000) { $pause = $pause * 2; }
        }
    }
}

def c as mqtt.Client init mqtt.connect(mqtt.Options{host: "127.0.0.1",
    port: 11883, clientId: "logger", keepalive: 30,
    security: transport.Security.None, username: "demo", password: "changeme"});
$c = mqtt.subscribe($c, "home/#");
def seen as int init 0;
while ($seen < 2) {
    try {
        def m as mqtt.Message init mqtt.receive($c);
        io.printf("%s = %s\n", $m.topic, encoding.decode("utf-8", $m.payload));
        $seen = $seen + 1;
    } catch (e) {
        io.printf("lost the broker (%s)\n", $e.kind);
        $c = reconnect($c);
        io.printf("back, %d subscription(s) restored\n", len($c.subs));
    }
}
mqtt.disconnect($c);

use io;
import "mqtt.j" as mqtt;
import "transport.j" as transport;
def c as mqtt.Client init mqtt.connect(mqtt.Options{host: "127.0.0.1", port: 11883,
    clientId: "bug2", keepalive: 30, security: transport.Security.None,
    username: "demo", password: "changeme"});
$c = mqtt.subscribe($c, "a");
mqtt.publish($c, "a", "x");
try {
    $c = mqtt.subscribe($c, "b");
    io.printf("ok\n");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}

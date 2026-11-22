use io;
use net;
use encoding;
import "mqtt.j" as mqtt;
import "transport.j" as transport;

func opts(id as string) {
    return mqtt.Options{host: "127.0.0.1", port: 11883, clientId: $id,
        keepalive: 30, security: transport.Security.None,
        username: "demo", password: "changeme"};
}
func show(c as mqtt.Client) {
    for (def m in mqtt.poll($c, 500)) {
        io.printf("%s = %s\n", $m.topic,
            encoding.decode("utf-8", $m.payload));
    }
}
def will as mqtt.Will init mqtt.Will{topic: "status/sensor7",
    payload: encoding.encode("utf-8", "offline"), qos: 1, retain: true};
def sensor as mqtt.Client init mqtt.connectWith(opts("sensor7"), $will, true);
mqtt.publishRetain($sensor, "status/sensor7", "online", true);

def late as mqtt.Client init mqtt.connect(opts("late"));   # joins afterwards
$late = mqtt.subscribe($late, "status/+");
show($late);                    # the retained "online", at once
net.close($sensor.conn);        # power cut: no DISCONNECT
show($late);                    # the broker publishes the will
mqtt.disconnect($late);

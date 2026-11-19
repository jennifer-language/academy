use io;
use convert;
import "mqtt.j" as mqtt;
import "transport.j" as transport;

func open(id as string) {
    return mqtt.connect(mqtt.Options{host: "127.0.0.1", port: 11883,
        clientId: $id, keepalive: 30, security: transport.Security.None,
        username: "demo", password: "changeme"});
}
def sub as mqtt.Client init open("dashboard");
$sub = mqtt.subscribe($sub, "home/+/temp");      # one level
$sub = mqtt.subscribeQos1($sub, "alarm/#");      # any depth
def pub as mqtt.Client init open("sensors");
mqtt.publish($pub, "home/kitchen/temp", "21.5");
mqtt.publish($pub, "home/kitchen/humidity", "48");
mqtt.publish($pub, "home/garage/temp", "9.0");
mqtt.publishQos1($pub, "alarm/garage/door",
    convert.bytesFromString("utf-8", "open"), false);
while (true) {
    def got as list of mqtt.Message init mqtt.poll($sub, 500);
    if (len($got) == 0) {
        break;
    }
    io.printf("%s = %s\n", $got[0].topic,
        convert.stringFromBytes("utf-8", $got[0].payload));
}
mqtt.disconnect($pub);
mqtt.disconnect($sub);

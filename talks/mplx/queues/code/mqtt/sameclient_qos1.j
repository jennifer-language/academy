use io;
use encoding;
import "mqtt.j" as mqtt;
import "transport.j" as transport;
def c as mqtt.Client init mqtt.connect(mqtt.Options{host: "127.0.0.1", port: 11883,
    clientId: "bug", keepalive: 30, security: transport.Security.None,
    username: "demo", password: "changeme"});
$c = mqtt.subscribeQos1($c, "commands/#");
mqtt.publishQos1($c, "commands/reboot", encoding.encode("utf-8", "now"), false);
io.printf("published\n");
def got as list of mqtt.Message init mqtt.poll($c, 2000);
io.printf("poll got %d message(s)\n", len($got));
mqtt.disconnect($c);

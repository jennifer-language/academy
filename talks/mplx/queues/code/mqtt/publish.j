import "mqtt.j" as mqtt;
import "transport.j" as transport;
def c as mqtt.Client init mqtt.connect(mqtt.Options{host: "127.0.0.1", port: 11883,
    clientId: "p", keepalive: 30, security: transport.Security.None, username: "demo", password: "changeme"});
mqtt.publish($c, "home/hall/light", "on");
mqtt.disconnect($c);

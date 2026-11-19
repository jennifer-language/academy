use io;
import "amqp.j" as amqp;
import "mqtt.j" as mqtt;
import "redis.j" as redis;
import "transport.j" as transport;

func tryAmqp(label as string, port as int, password as string, queue as string) {
    try {
        def c as amqp.Conn init amqp.connect(amqp.withPort(
            amqp.options("127.0.0.1", "demo", $password), $port));
        amqp.get($c, $queue, false);
    } catch (e) {
        io.printf("%s -> %s: %s\n", $label, $e.kind, $e.message);
    }
}
tryAmqp("no broker", 25999, "changeme", "billing");
tryAmqp("password", 25672, "wrong", "billing");
tryAmqp("no queue", 25672, "changeme", "jobs");

func tryMqtt(label as string, port as int, password as string) {
    try {
        mqtt.connect(mqtt.Options{host: "127.0.0.1", port: $port,
            clientId: "err", keepalive: 30, security: transport.Security.None,
            username: "demo", password: $password});
    } catch (e) {
        io.printf("%s -> %s: %s\n", $label, $e.kind, $e.message);
    }
}
tryMqtt("no broker", 11999, "changeme");
tryMqtt("password", 11883, "wrong");
try {
    redis.connect(redis.Options{host: "127.0.0.1", port: 16999,
        security: transport.Security.None, user: "", password: "", db: 0});
} catch (e) {
    io.printf("%s -> %s: %s\n", "redis", $e.kind, $e.message);
}

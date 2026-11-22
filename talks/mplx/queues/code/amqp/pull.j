use io;
use json;
use encoding;
import "amqp.j" as amqp;

func text(b as bytes) {
    return encoding.decode("utf-8", $b);
}

def c as amqp.Conn init amqp.connect(amqp.withPort(
    amqp.options("127.0.0.1", "demo", "changeme"), 25672));
while (true) {
    def m as amqp.Message init amqp.get($c, "billing", false);
    if ($m.empty) { break; }
    try {
        def v as json.Value init json.decode(text($m.body));
        io.printf("bill order %d\n", json.asInt($v, "/order"));
        amqp.ack($c, $m.deliveryTag);
    } catch (e) {   # json.decode failed: kind "runtime"
        amqp.nack($c, $m.deliveryTag, false);   # drop, or dead-letter
    }
}
amqp.close($c);

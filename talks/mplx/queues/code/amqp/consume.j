use io;
use task;
use encoding;
import "amqp.j" as amqp;

func text(b as bytes) {
    return encoding.decode("utf-8", $b);
}

def opts as amqp.Options init amqp.withPort(
    amqp.options("127.0.0.1", "demo", "changeme"), 25672);
def worker as task of int init spawn {
    def c as amqp.Conn init amqp.connect($opts);   # its own connection
    def tag as string init amqp.consume($c, "billing", false);
    for (def i in 0..3) {
        def d as amqp.Delivery init amqp.receiveDelivery($c);
        io.printf("%s redelivered=%t\n", text($d.body), $d.redelivered);
        amqp.ack($c, $d.deliveryTag);
    }
    amqp.cancelConsume($c, $tag);
    amqp.close($c);
    return 3;
};
io.printf("worker handled %d\n", task.wait($worker));

use io;
use time;
use encoding;
import "amqp.j" as amqp;

def c as amqp.Conn init amqp.connect(amqp.withPort(
    amqp.options("127.0.0.1", "demo", "changeme"), 25672));
amqp.consume($c, "billing", false);
def d as amqp.Delivery init amqp.receiveDelivery($c);
io.printf("got %s, crashing before the ack\n",
    encoding.decode("utf-8", $d.body));
time.sleep(time.fromSeconds(2));
exit(1);

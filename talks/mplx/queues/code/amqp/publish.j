use io;
use convert;
import "amqp.j" as amqp;

def opts as amqp.Options init amqp.withPort(
    amqp.options("127.0.0.1", "demo", "changeme"), 25672);
def c as amqp.Conn init amqp.connect($opts);
amqp.declareExchange($c, "orders", "topic");
def q as amqp.QueueInfo init amqp.declareQueue($c, "billing", true);
amqp.bindQueue($c, "billing", "orders", "order.*");
amqp.confirmSelect($c);
def p as amqp.Properties init amqp.Properties{contentType: "application/json",
    persistent: true, correlationId: "", replyTo: ""};
for (def id in [17, 18, 19]) {
    def body as string init "\{\"order\": {$id}\}";
    amqp.publishWith($c, "orders", "order.created",
        convert.bytesFromString("utf-8", $body), $p);
    io.printf("order %d confirmed: %t\n", $id, amqp.waitConfirm($c));
}
amqp.publishText($c, "orders", "invoice.sent", "nobody is bound");
io.printf("unroutable confirmed: %t\n", amqp.waitConfirm($c));
io.printf("billing had %d ready\n", $q.messageCount);
amqp.close($c);

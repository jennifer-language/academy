import "amqp.j" as amqp;
def c as amqp.Conn init amqp.connect(amqp.withPort(amqp.options("127.0.0.1", "demo", "changeme"), 25672));
amqp.publishText($c, "orders", "order.created", "\{\"order\": 20\}");
amqp.close($c);

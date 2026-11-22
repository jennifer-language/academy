# "Error kinds you can rely on": one catch per generic kind. The net case
# connects to a port on 127.0.0.1 where nothing listens (refused).
use io;
use json;
use net;
use strings;
use task;
use time;
use channel;

func show(what as string, e as Error) {
    io.printf("%s: kind %s\n", $what, $e.kind);
}

try {
    json.decode(strings.replicate("[", 5000));
} catch (e) {
    show("limit", $e);
}

def slow as task of int init spawn {
    time.sleep(time.fromSeconds(5));
    return 1;
};
try {
    task.waitTimeout($slow, 100);
} catch (e) {
    show("timeout", $e);
}
task.cancel($slow);
try {
    task.wait($slow);
} catch (e) {
    show("cancelled", $e);
}

def ch as channel of int init channel.make(1);
channel.close($ch);
try {
    channel.recv($ch);
} catch (e) {
    show("closed", $e);
}

try {
    net.connect("127.0.0.1:1");
} catch (e) {
    io.printf("net: kind %s, reason %s, sent %v, replied %v\n",
        $e.kind, $e.reason, $e.sent, $e.replied);
}

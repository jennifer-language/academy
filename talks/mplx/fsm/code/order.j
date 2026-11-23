use io;
import "@deckyard/fsm/" as fsm;
import "./orders.j" as orders;

def m as fsm.Machine init orders.build();
def ctx as map of string to string init {"user": "ada", "role": "clerk"};
def state as string init $m.initial;

$state = fsm.fire($m, $state, "submit", $ctx).target;
io.printf("%s, can: %v\n", $state, fsm.events($m, $state, $ctx));
try {
    fsm.fire($m, $state, "approve", $ctx);
} catch (e) {
    io.printf("%s\n", $e.message);
}

$ctx["role"] = "manager";
def s as fsm.Step init fsm.fire($m, $state, "approve", $ctx);
$state = $s.target;
io.printf("%s by %s\n", $state, $s.ctx["approvedBy"]);

io.printf("ship? %v\n", fsm.can($m, $state, "ship", $ctx));
$ctx["paid"] = "yes";
$state = fsm.fire($m, $state, "ship", $ctx).target;
io.printf("%s, final: %v\n", $state, fsm.isFinal($m, $state));

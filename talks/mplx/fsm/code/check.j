use io;
import "@deckyard/fsm/" as fsm;

# A draft of the order machine with three mistakes in it.
def m as fsm.Machine init fsm.machine("order", "draft");
$m = fsm.addStates($m, ["review", "approved", "rejected", "archived"]);
$m = fsm.addFinals($m, ["rejected"]);
$m = fsm.addTransition($m, "submit", ["draft"], "review");
$m = fsm.addTransition($m, "approve", ["review"], "approved");
$m = fsm.addTransition($m, "reject", ["review"], "rejected");
$m = fsm.addTransition($m, "reopen", ["rejected"], "review");

for (def p in fsm.check($m)) { io.printf("%s: %s\n", $p.kind, $p.message); }

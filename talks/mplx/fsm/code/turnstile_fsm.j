use io;
import "@deckyard/fsm/" as fsm;

def m as fsm.Machine init fsm.machine("turnstile", "locked");
$m = fsm.addStates($m, ["unlocked"]);
$m = fsm.addTransition($m, "coin", ["locked", "unlocked"], "unlocked");
$m = fsm.addTransition($m, "push", ["locked", "unlocked"], "locked");

def state as string init $m.initial;
for (def e in ["coin", "push", "push", "coin"]) {
    $state = fsm.fire($m, $state, $e, {}).target;
    io.printf("%s -> %s\n", $e, $state);
}
io.printf("from %s: %v\n", $state, fsm.events($m, $state, {}));

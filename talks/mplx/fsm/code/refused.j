use io;
import "@deckyard/fsm/" as fsm;

def m as fsm.Machine init fsm.machine("turnstile", "locked");
$m = fsm.addStates($m, ["unlocked"]);
$m = fsm.addTransition($m, "coin", ["locked", "unlocked"], "unlocked");
$m = fsm.addTransition($m, "push", ["locked", "unlocked"], "locked");

try {
    fsm.fire($m, "locked", "kick", {});                          # no such transition
} catch (e) {
    io.printf("%s\n", $e.message);
}
try {
    fsm.fire($m, "jammed", "push", {});                          # not a state
} catch (e) {
    io.printf("%s\n", $e.message);
}
try {
    $m = fsm.addTransition($m, "kick", ["lockd"], "unlocked");   # typo
} catch (e) {
    io.printf("%s\n", $e.message);
}
try {
    $m = fsm.addTransition($m, "coin", ["locked"], "locked");    # shadowed
} catch (e) {
    io.printf("%s\n", $e.message);
}

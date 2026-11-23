use io;
import "@deckyard/fsm/" as fsm;
import "./orders.j" as orders;

# The state is a plain string, kept where the order is kept.
def struct Order { id as string, state as string };

def m as fsm.Machine init orders.build();
def rows as list of Order init [
    Order{id: "A1", state: "review"},
    Order{id: "A2", state: "shipped"},
    Order{id: "A3", state: "pending"}       # written by an older version
];
for (def o in $rows) {
    if (not fsm.isState($m, $o.state)) {
        io.printf("%s: unknown state %s, migrate it\n", $o.id, $o.state);
    } elseif (fsm.isFinal($m, $o.state)) {
        io.printf("%s: %s, closed\n", $o.id, $o.state);
    } else {
        io.printf("%s: next %v\n", $o.id, fsm.events($m, $o.state, {}));
    }
}

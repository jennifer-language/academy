use testing;
import "@deckyard/fsm/" as fsm;
import "./orders.j" as orders;

def struct Path { events as list of string, want as string };

/** Fire each event in turn from the initial state; return the last state. */
func walk(m as fsm.Machine, events as list of string, ctx as map of string to string) {
    def state as string init $m.initial;
    for (def e in $events) {
        $state = fsm.fire($m, $state, $e, $ctx).target;
    }
    return $state;
}

func testTheDefinitionIsClean() {
    testing.assertEqual(len(fsm.check(orders.build())), 0);
}

func testPaths() {
    def m as fsm.Machine init orders.build();
    def ctx as map of string to string init
        {"user": "ada", "role": "manager", "paid": "yes"};
    def paths as list of Path init [
        Path{events: ["submit", "approve", "ship"], want: "shipped"},
        Path{events: ["submit", "edit", "submit", "reject"], want: "rejected"},
        Path{events: ["submit", "approve", "cancel"], want: "cancelled"}
    ];
    for (def p in $paths) {
        testing.assertEqual(walk($m, $p.events, $ctx), $p.want);
    }
}

func testGuardsDecideTheEvents() {
    def m as fsm.Machine init orders.build();
    testing.assertEqual(
        fsm.events($m, "review", {"role": "clerk"}),
        ["edit", "reject", "cancel"]);
    testing.assertEqual(
        fsm.events($m, "review", {"role": "manager"}),
        ["edit", "approve", "reject", "cancel"]);
}

func clerkApproves() {
    walk(orders.build(), ["submit", "approve"], {"user": "bo", "role": "clerk"});
}

func shipUnpaid() {
    walk(orders.build(), ["submit", "approve", "ship"],
        {"user": "ada", "role": "manager"});
}

func testRefusedEventsThrow() {
    testing.assertThrows("clerkApproves", "fsm");
    testing.assertThrows("shipUnpaid", "fsm");
}

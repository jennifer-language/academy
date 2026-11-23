use maps;
import "@deckyard/fsm/" as fsm;

/** A guard: only a manager approves. */
export func isManager(s as fsm.Step) {
    return maps.has($s.ctx, "role") and $s.ctx["role"] == "manager";
}

/** A guard: only a paid order ships. */
export func isPaid(s as fsm.Step) {
    return maps.has($s.ctx, "paid") and $s.ctx["paid"] == "yes";
}

/** An enter hook: record who approved. */
export func stamp(s as fsm.Step) {
    def c as map of string to string init $s.ctx;
    $c["approvedBy"] = $c["user"];
    return $c;
}

/** The guards and hooks a document may name, for fsm.load. */
export func functions() {
    return {"isManager": isManager, "isPaid": isPaid, "stamp": stamp};
}

/** The order life cycle. */
export func build() {
    def m as fsm.Machine init fsm.machine("order", "draft");
    $m = fsm.addStates($m,
        ["review", "approved", "rejected", "shipped", "cancelled"]);
    $m = fsm.addFinals($m, ["rejected", "shipped", "cancelled"]);
    $m = fsm.addTransition($m, "submit", ["draft"], "review");
    $m = fsm.addTransition($m, "edit", ["review"], "draft");
    $m = fsm.addGuarded($m, "approve", ["review"], "approved", isManager);
    $m = fsm.addTransition($m, "reject", ["review"], "rejected");
    $m = fsm.addGuarded($m, "ship", ["approved"], "shipped", isPaid);
    $m = fsm.addTransition($m, "cancel",
        ["draft", "review", "approved"], "cancelled");
    $m = fsm.onEnter($m, "approved", stamp);
    return $m;
}

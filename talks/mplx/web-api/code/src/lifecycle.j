# lifecycle.j - the order lifecycle as a state machine

import "@deckyard/fsm/" as fsm;

export func machine() {
    def m as fsm.Machine init fsm.machine("order", "new");
    $m = fsm.addStates($m, ["paid", "shipped", "delivered", "cancelled"]);
    $m = fsm.addFinals($m, ["delivered", "cancelled"]);
    $m = fsm.addTransition($m, "pay", ["new"], "paid");
    $m = fsm.addTransition($m, "ship", ["paid"], "shipped");
    $m = fsm.addTransition($m, "deliver", ["shipped"], "delivered");
    $m = fsm.addTransition($m, "cancel", ["new"], "cancelled");
    $m = fsm.addGuarded($m, "cancel", ["paid"], "cancelled", isAdmin);
    return $m;
}

# Cancelling a paid order means a refund: admins only.
func isAdmin(step as fsm.Step) {
    return $step.ctx["role"] == "admin";
}

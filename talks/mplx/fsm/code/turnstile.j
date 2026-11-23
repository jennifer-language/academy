use io;

def enum State { Locked, Unlocked };
def enum Event { Coin, Push };

func next(state as State, event as Event) {
    match ($state) {
        when Locked {
            match ($event) {
                when Coin { return State.Unlocked; }
                when Push { return State.Locked; }
            }
        }
        when Unlocked {
            match ($event) {
                when Coin { return State.Unlocked; }
                when Push { return State.Locked; }
            }
        }
    }
}

def s as State init State.Locked;
for (def e in [Event.Coin, Event.Push, Event.Push, Event.Coin]) {
    $s = next($s, $e);
    io.printf("%v -> %v\n", $e, $s);
}

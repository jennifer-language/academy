use fs;
use io;
import "@deckyard/fsm/" as fsm;
import "./orders.j" as orders;

def m as fsm.Machine init
    fsm.load(fs.readString("order.toml"), "toml", orders.functions());
io.printf("same as orders.build(): %v\n", $m == orders.build());

# A typo in a key is refused, with the place in the document.
def typo as string init '{"name": "door", "initial": "shut",
  "transitions": [{"event": "open", "from": "shut", "to": "shut", "gaurd": "x"}]}';
try {
    fsm.load($typo, "json", {});
} catch (e) {
    io.printf("%s\n", $e.message);
}

io.printf("%s", fsm.mermaid($m));

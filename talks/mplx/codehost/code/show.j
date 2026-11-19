# Release 1.3.0 as each forge reports it, normalised, and its notes.
use io;

import "./forges.j" as forges;
import "@deckyard/codehost/" as codehost;

def notes as string init "";
for (def s in forges.load()) {
    def f as codehost.Forge init $s.forge;
    def r as codehost.Release init codehost.release($f, $s.repo, "1.3.0");
    io.printf("%s: id %d, %d assets\n", $f.backend, $r.id, len($r.assets));
    for (def a in $r.assets) {
        io.printf("  %s, size %d\n", $a.name, $a.size);
    }
    $notes = $r.body;
}
io.printf("\n%s", $notes);

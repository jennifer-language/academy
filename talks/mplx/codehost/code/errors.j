# Release 1.3.0 a second time, to see how each forge refuses.
use io;

import "./forges.j" as forges;
import "@deckyard/codehost/" as codehost;

for (def s in forges.load()) {
    try {
        codehost.createRelease(
            $s.forge, $s.repo, "1.3.0", "", "1.3.0", "again", false);
    } catch (e) {
        if ($e.kind != codehost.ERROR_KIND) {
            throw $e;
        }
        def ce as codehost.CodehostError init $e;
        io.printf("%s %d: %s\n", $ce.backend, $ce.status, $ce.message);
    }
}

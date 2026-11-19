# One loop over every forge: the repository and its open issues.
use io;
use strings;

import "./forges.j" as forges;
import "@deckyard/codehost/" as codehost;

for (def s in forges.load()) {
    def f as codehost.Forge init $s.forge;
    def r as codehost.Repository init codehost.repository($f, $s.repo);
    io.printf("%s: %s, default branch %s\n",
        $f.backend, $r.fullName, $r.defaultBranch);
    for (def i in codehost.issues($f, $s.repo, "open")) {
        io.printf("  #%d %s [%s]\n",
            $i.number, $i.title, strings.join($i.labels, ", "));
    }
}

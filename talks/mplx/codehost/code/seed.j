# Setup, not on a slide: open tempo's two issues on every forge but the
# GitHub stand-in, which has them already.
use io;

import "./forges.j" as forges;
import "@deckyard/codehost/" as codehost;

for (def s in forges.load()) {
    if ($s.forge.backend != "github") {
        codehost.createIssue($s.forge, $s.repo, "Duration parser drops seconds", "");
        codehost.createIssue($s.forge, $s.repo, "Document the --sum flag", "");
        io.printf("seeded %s\n", $s.forge.backend);
    }
}

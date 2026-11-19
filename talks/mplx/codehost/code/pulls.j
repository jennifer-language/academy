# A branch, a commit and a draft change request on each forge, then a
# rebase merge, which only some forges do.
use convert;
use io;

import "./forges.j" as forges;
import "@deckyard/codehost/" as codehost;

for (def s in forges.load()) {
    def f as codehost.Forge init $s.forge;
    def fix as string init "zero-seconds";
    codehost.createBranch($f, $s.repo, $fix, "");
    codehost.writeFile($f, $s.repo, "ZERO",
        convert.bytesFromString("utf-8", "0s\n"), "format: 0s", $fix);
    def c as codehost.ChangeRequest init codehost.createChangeRequest(
        $f, $s.repo, $fix, "main", "Print 0s for zero", "Fixes #1.", true);
    io.printf("%s: !%d %s, %s, draft %s, mergeable %s\n",
        $f.backend, $c.number, $c.title, $c.state,
        convert.toString($c.isDraft), convert.toString($c.mergeable));
    try {
        codehost.mergeChangeRequest($f, $s.repo, $c.number, "rebase", true);
    } catch (e) {
        if ($e.kind != codehost.ERROR_KIND) {
            throw $e;
        }
        io.printf("%s: %s\n", $f.backend, $e.message);
    }
}

# Stands in for CI, not on a slide: report a check on a commit, on every
# forge in forges.toml.
#   jennifer run ci.j <sha> <context> <state>
use io;
use os;

import "./forges.j" as forges;
import "@deckyard/codehost/" as codehost;

def sha as string init os.ARGS[1];
for (def s in forges.load()) {
    def st as codehost.CommitStatus init codehost.setCommitStatus(
        $s.forge, $s.repo, $sha, os.ARGS[3], os.ARGS[2], "tools/check.sh", "");
    io.printf("%s: %s %s (%s)\n", $s.forge.backend, $st.context, $st.state, $st.forgeState);
}

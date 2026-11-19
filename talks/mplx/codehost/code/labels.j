# Give every forge the labels of the first one in forges.toml, then
# label each mirrored issue as it is labelled there (by its title).
use io;
use lists;
use strings;

import "./forges.j" as forges;
import "@deckyard/codehost/" as codehost;

def sites as list of forges.Site init forges.load();
def src as forges.Site init $sites[0];
def wanted as list of codehost.Label init
    codehost.labels($src.forge, $src.repo);
def issues as list of codehost.Issue init
    codehost.issues($src.forge, $src.repo, "open");

for (def s in $sites[1..len($sites)]) {
    def f as codehost.Forge init $s.forge;
    def have as list of string init [];
    for (def l in codehost.labels($f, $s.repo)) {
        $have[] = $l.name;
    }
    for (def l in $wanted) {
        if (not lists.contains($have, $l.name)) {
            codehost.createLabel(
                $f, $s.repo, $l.name, $l.color, $l.description);
            io.printf("%s: created %s\n", $f.backend, $l.name);
        }
    }
    for (def mine in codehost.issues($f, $s.repo, "open")) {
        for (def i in $issues) {
            if ($i.title == $mine.title) {
                def now as list of string init codehost.setIssueLabels(
                    $f, $s.repo, $mine.number, $i.labels);
                io.printf("%s: #%d %s\n",
                    $f.backend, $mine.number, strings.join($now, ", "));
            }
        }
    }
}

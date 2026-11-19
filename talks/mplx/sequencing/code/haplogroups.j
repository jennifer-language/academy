# SPDX-License-Identifier: CC-BY-4.0
# A mitoLEAF-shaped phylogeny with @deckyard/mitoleaf: lineages, motifs,
# back mutations, and the nearest haplogroup. data/tree.xml is the
# deck's seven-haplogroup synthetic test tree, not the real phylogeny.
#
#   jennifer run haplogroups.j

use convert;
use fs;
use io;
use strings;

import "@deckyard/mitoleaf/" as mitoleaf;
import "@deckyard/forensicgenetics/lineage.j" as lineage;

def t as mitoleaf.Tree init mitoleaf.parse(fs.readString("data/tree.xml"));
io.printf("root %s, %d haplogroups\n", $t.root,
    len(mitoleaf.haplogroups($t)));
for (def hg in mitoleaf.path($t, "L0a")) {
    io.printf("%s|pad=7 adds %s|pad=22 -> %s\n", $hg,
        strings.join(mitoleaf.motif($t, $hg), " "), strings.join(
        lineage.mtDesignations(mitoleaf.haplotype($t, $hg)), " "));
}
def item as mitoleaf.MotifItem init mitoleaf.parseMotifItem("A263");
io.printf("A263: reversion %v at %d\n", $item.reversion, $item.position);

def obs as lineage.MtHaplotype init lineage.mtHaplotype("obs",
    ["16024-16362", "1-417"], "16278T 73G 315.1C");
def m as mitoleaf.Match init mitoleaf.assign($t, $obs);
io.printf("nearest %s, distance %d, ranges agree: %v\n", $m.haplogroup,
    $m.distance, lineage.mtRangesAgree(mitoleaf.haplotype($t, "L0a"), $obs));
def ds as list of string init [];
for (def hg in ["mt-MRCA", "L0", "L0a", "L0a1", "L1"]) {
    $ds[] = $hg + " " + convert.toString(mitoleaf.distance($t, $hg, $obs));
}
io.printf("  %s\n", strings.join($ds, ", "));
try {
    lineage.mtHaplotype("bad", ["1-417"], "73G 73A");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}

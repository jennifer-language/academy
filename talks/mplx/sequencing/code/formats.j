# SPDX-License-Identifier: CC-BY-4.0
# One line at a time: SAM, VCF and BED records with @deckyard/ngs, and
# interval arithmetic on them. The records are made up.
#
#   jennifer run formats.j

use io;

import "@deckyard/ngs/sam.j" as sam;
import "@deckyard/ngs/vcf.j" as vcf;
import "@deckyard/ngs/bed.j" as bed;
import "@deckyard/ngs/intervals.j" as intervals;

def a as sam.Record init sam.parse(
    "r1\t16\tchrM\t16201\t60\t40M2I58M\t*\t0\t0\t*\t*\tNM:i:3");
io.printf("%s %s pos %d, covers %d reference bases, NM %s\n", $a.qname,
    sam.strandOf($a), $a.pos, sam.referenceLength($a.cigar),
    sam.tagValue($a, "NM", "?"));
def read as intervals.Interval init sam.toInterval($a);
io.printf("as an interval: %s\n", intervals.toBed3($read));

def v as vcf.Variant init vcf.parse(
    "chrM\t16278\t.\tC\tT\t50\tPASS\tDP=31");
io.printf("%s:%d %s>%v snv=%v passed=%v DP=%s\n", $v.chrom, $v.pos, $v.ref,
    $v.alt, vcf.isSnv($v), vcf.passed($v), vcf.info($v, "DP", "0"));

def target as intervals.Interval init bed.parse("chrM\t16023\t16365\tHVS1");
io.printf("variant in target: %v; read overlaps target by %d bases\n",
    intervals.contains($target, vcf.toInterval($v)),
    intervals.overlapLength($read, $target));
try {
    sam.parseCigar("40M2");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}

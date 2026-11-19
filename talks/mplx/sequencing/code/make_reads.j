# SPDX-License-Identifier: CC-BY-4.0
# Write data/reads.fastq: 2000 made-up 100-base reads whose quality falls
# towards the 3' end; one read in eight is a short insert that runs into
# the TruSeq adapter. Seeded, so every run writes the same file.
#
#   jennifer run make_reads.j

use convert;
use fs;
use math;
use strings;

import "@deckyard/bioinformatics/" as bioseq;
import "@deckyard/ngs/fastq.j" as fastq;
import "@deckyard/ngs/qc.j" as qc;

def const READS as int init 2000;
def const LENGTH as int init 100;

math.randSeed(26);
def out as list of string init [];
for (def n in 0..READS) {
    def seq as string init bioseq.randomDna(LENGTH);
    if ($n % 8 == 0) {
        def insert as int init math.randInt(40, 80);
        $seq = $seq[0..$insert] + qc.ADAPTER_TRUSEQ + bioseq.randomDna(LENGTH);
        $seq = $seq[0..LENGTH];
    }
    def q as list of string init [];
    for (def i in 0..LENGTH) {
        def phred as int init 38 - $i * $i // 450 + math.randInt(-4, 2);
        if ($phred < 2) {
            $phred = 2;
        }
        $q[] = convert.fromCodepoint(33 + $phred);
    }
    def r as fastq.Read init fastq.Read{
        id: "syn" + convert.toString($n + 1),
        desc: "",
        seq: $seq,
        qual: strings.join($q, "")
    };
    $out[] = fastq.format($r);
}
fs.mkdirAll("data");
fs.writeString("data/reads.fastq", strings.join($out, ""));

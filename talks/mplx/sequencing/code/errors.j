# SPDX-License-Identifier: CC-BY-4.0
# Malformed and oversized input: what each deck throws, by kind.
#
#   jennifer run errors.j

use binary;
use fs;
use io;

import "@deckyard/abif/" as abif;
import "@deckyard/bioinformatics/" as bioseq;
import "@deckyard/ngs/fastq.j" as fastq;
import "@deckyard/statfiles/" as statfiles;
import "@deckyard/mitoleaf/" as mitoleaf;
import "@deckyard/forensicgenetics/lineage.j" as lineage;

# The input and the kind, then the message cut to 64 characters.
func show(what as string, e as Error) {
    def msg as string init $e.message;
    if (len($msg) > 64) {
        $msg = $msg[0..61] + "...";
    }
    io.printf("%s: %s\n  %s\n", $what, $e.kind, $msg);
}

try {
    abif.open("data/fake.ab1");
} catch (e) {
    show("fake.ab1", $e);
}
try {
    abif.parse(binary.slice(fs.readBytes("data/3730.ab1"), 0, 200000));
} catch (e) {
    show("cut .ab1", $e);
}
try {
    bioseq.parseFasta(">x\nACGT\n>\nACGT\n");
} catch (e) {
    show("FASTA", $e);
}
try {
    fastq.parse("@r1", "ACGT", "+", "III");
} catch (e) {
    show("FASTQ", $e);
}
try {
    statfiles.read(fs.readBytes("data/refs.fasta"));
} catch (e) {
    show("not a .dta", $e);
}
def opts as statfiles.Options init statfiles.options();
$opts.maxCells = 20;
try {
    statfiles.readWith(fs.readBytes("data/study.dta"), $opts);
} catch (e) {
    show("maxCells 20", $e);
}
def al as bioseq.AlignOptions init bioseq.dnaOptions();
$al.maxCells = 10000;
try {
    bioseq.alignGlobal(bioseq.randomDna(200), bioseq.randomDna(200), $al);
} catch (e) {
    show("align 200x200", $e);
}
try {
    lineage.align(bioseq.randomDna(20000), bioseq.randomDna(20000), 1);
} catch (e) {
    show("align 20 kb", $e);
}
def t as mitoleaf.Tree init mitoleaf.parse(fs.readString("data/tree.xml"));
try {
    mitoleaf.path($t, "H1");
} catch (e) {
    show("haplogroup H1", $e);
}

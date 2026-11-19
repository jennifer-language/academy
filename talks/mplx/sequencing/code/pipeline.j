# SPDX-License-Identifier: CC-BY-4.0
# Two Sanger traces -> quality-trimmed reads -> differences against a
# reference -> nearest haplogroup. Every input is synthetic: run
# `python3 make_data.py` first; tree.xml is deck-mitoleaf's test tree.
#
#   jennifer run pipeline.j

use convert;
use math;
use fs;
use io;
use strings;

import "@deckyard/abif/" as abif;
import "@deckyard/bioinformatics/" as bioseq;
import "@deckyard/ngs/fastq.j" as fastq;
import "@deckyard/ngs/trim.j" as trim;
import "@deckyard/forensicgenetics/lineage.j" as lineage;
import "@deckyard/mitoleaf/" as mitoleaf;

def const MIN_Q as int init 20;
def const WINDOW as int init 10;

# The base calls of a trace as a FASTQ read (Phred + 33, capped at 93).
func toRead(path as string) {
    def f as abif.File init abif.open($path);
    def c as abif.Calls init abif.calls($f);
    def q as list of string init [];
    for (def v in $c.qualities) {
        $q[] = convert.fromCodepoint(33 + math.min($v, 93));
    }
    return fastq.parse("@" + abif.info($f).sample, $c.bases, "+",
        strings.join($q, ""));
}

# First position whose window of WINDOW bases averages MIN_Q or more.
func goodStart(r as fastq.Read) {
    def q as list of int init fastq.qualities($r, fastq.PHRED33);
    for (def i in 0..len($q) - WINDOW) {
        def sum as int init 0;
        for (def k in $i..$i + WINDOW) {
            $sum = $sum + $q[$k];
        }
        if ($sum >= MIN_Q * WINDOW) {
            return $i;
        }
    }
    return len($q);
}

# Trim both ends: the 5' end by goodStart, the 3' end by ngs's window.
func trimmed(r as fastq.Read) {
    def t as fastq.Read init trim.clipFixed($r, goodStart($r), 0);
    return trim.clipQuality($t, MIN_Q, WINDOW, fastq.PHRED33);
}

# The read's differences against the reference region it covers.
func differences(id as string, ref as string, refStart as int,
        s as string) {
    def al as bioseq.Alignment init bioseq.alignLocal($ref, $s,
        bioseq.dnaOptions());
    def r as string init strings.replace($al.a, "-", "");
    def x as string init strings.replace($al.b, "-", "");
    return lineage.mtHaplotypeFrom($id, $r, $x, $refStart + $al.startA);
}

def refs as map of string to string init {};
for (def rec in bioseq.parseFasta(fs.readString("data/refs.fasta"))) {
    $refs[$rec.id] = $rec.sequence;
}
def runs as list of list of string init [
    ["data/mito-hvs1.ab1", "HVS1", "16024"],
    ["data/mito-hvs2.ab1", "HVS2", "1"]];

def ranges as list of string init [];
def found as list of string init [];
for (def run in $runs) {
    def raw as fastq.Read init toRead($run[0]);
    def r as fastq.Read init trimmed($raw);
    io.printf("%s: %d bases, %d kept, mean Q %f|prec=1\n", $r.id,
        fastq.length($raw), fastq.length($r),
        fastq.meanQuality($r, fastq.PHRED33));
    def h as lineage.MtHaplotype init differences($r.id, $refs[$run[1]],
        convert.toInt($run[2]), $r.seq);
    io.printf("  %v %v\n", $h.ranges, lineage.mtDesignations($h));
    $ranges[] = $h.ranges[0];
    for (def d in lineage.mtDesignations($h)) {
        $found[] = $d;
    }
}

def sample as lineage.MtHaplotype init lineage.mtHaplotype("sample",
    $ranges, strings.join($found, " "));
def tree as mitoleaf.Tree init mitoleaf.parse(fs.readString("data/tree.xml"));
def m as mitoleaf.Match init mitoleaf.assign($tree, $sample);
io.printf("nearest %s at distance %d, path %v\n", $m.haplogroup,
    $m.distance, mitoleaf.path($tree, $m.haplogroup));
io.printf("its haplotype %v\n",
    lineage.mtDesignations(mitoleaf.haplotype($tree, $m.haplogroup)));

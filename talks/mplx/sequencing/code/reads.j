# SPDX-License-Identifier: CC-BY-4.0
# Next-generation reads with @deckyard/ngs: stream a FASTQ file, run the
# one-pass QC report, then trim adapters and low-quality tails.
# Run `jennifer run make_reads.j` first.
#
#   jennifer run reads.j

use fs;
use io;

import "@deckyard/ngs/fastq.j" as fastq;
import "@deckyard/ngs/qc.j" as qc;
import "@deckyard/ngs/trim.j" as trim;

# streaming: one record at a time, gzip or plain
def r as fastq.Reader init fastq.open("data/reads.fastq");
def n as int init 0;
def low as int init 0;
while (fastq.hasNext($r)) {
    def rec as fastq.Read init fastq.next($r);
    $n = $n + 1;
    if (fastq.minQuality($rec, fastq.PHRED33) < 15) {
        $low = $low + 1;
    }
    if ($n == 1) {
        io.printf("%s: %d bases, mean Q %f|prec=1, last five %v\n", $rec.id,
            fastq.length($rec), fastq.meanQuality($rec, fastq.PHRED33),
            fastq.qualities(fastq.subseq($rec, 95, 100), fastq.PHRED33));
    }
}
fastq.close($r);
io.printf("%d reads, %d with a base below Q15\n\n", $n, $low);

# QC in one pass
def opts as qc.Options init qc.options();
$opts.perBase = true;
def rep as qc.Report init qc.analyze("data/reads.fastq", $opts);
io.printf("%s", qc.summary($rep));
def means as list of float init qc.perBaseMean($rep);
io.printf("mean Q at base 1: %f|prec=1, at base 100: %f|prec=1\n\n",
    $means[0], $means[99]);

fs.mkdirAll("out");
# trimming: adapters, a Q20 window of 4, then drop reads under 25 bases
def s as trim.Stats init trim.run("data/reads.fastq", "out/trimmed.fastq",
    trim.options());
io.printf("in %d reads, %d bases; out %d reads, %d bases\n", $s.readsIn,
    $s.basesIn, $s.readsOut, $s.basesOut);
io.printf("adapter-clipped %d, quality-trimmed %d, too short %d\n",
    $s.adapterTrimmed, $s.qualityTrimmed, $s.tooShort);

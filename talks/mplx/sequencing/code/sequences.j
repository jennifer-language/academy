# SPDX-License-Identifier: CC-BY-4.0
# DNA, RNA and protein with @deckyard/bioinformatics, on the base calls of
# Biopython's 3730.ab1 sample trace (see README.md for where it comes from).
#
#   jennifer run sequences.j

use io;

import "@deckyard/abif/" as abif;
import "@deckyard/bioinformatics/" as bioseq;

def s as string init abif.calls(abif.open("data/3730.ab1")).bases;
io.printf("%d bases, GC %f|prec=1 %%\n", len($s), bioseq.gcContent($s));

# the first ATG of the long open reading frame, and 60 bases from it
def start as int init bioseq.find($s, "ATGGTGAGCAAG")[0].start;
def cds as string init $s[$start..$start + 60];
io.printf("DNA      %s\n", $cds);
io.printf("RNA      %s\n", bioseq.transcribe($cds));
io.printf("revcomp  %s\n", bioseq.reverseComplement($cds));
io.printf("protein  %s\n", bioseq.translate($cds));

# the whole frame, up to the end of the read
def protein as string init bioseq.translate($s[$start..len($s)]);
io.printf("%d residues, stop codons: %d\n", len($protein),
    len(bioseq.find($protein, "*")));
for (def m in bioseq.find($protein, "MVSKGEE")) {
    io.printf("MVSKGEE at residue %d\n", $m.start + 1);
}
io.printf("linker %s\n", $protein[236..240]);

# motifs: an IUPAC pattern, and restriction sites
io.printf("start codon at %d\n", $start);
def k as bioseq.Match init bioseq.findIupac($s[0..120], "RNNATGG")[0];
io.printf("RNNATGG %s at %d, strand %d\n", $k.text, $k.start, $k.strand);
for (def site in bioseq.restrictionSites($s, ["EcoRI", "NcoI", "BamHI"])) {
    io.printf("%s %s at %d\n", $site.enzyme, $site.site, $site.start);
}

# FASTA out and back in
def recs as list of bioseq.Record init [
    bioseq.Record{id: "cds", description: "from 3730.ab1", sequence: $cds}];
def text as string init bioseq.writeFastaWrapped($recs, 40);
io.printf("%s", $text);
io.printf("%v\n", bioseq.parseFasta($text)[0].id);
try {
    bioseq.reverseComplement("ACGTX");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}

# Sequencing data with Jennifer: the programs

The full programs behind the slides, for Jennifer 0.27.0. Run everything from
this folder.

## Setup

```sh
jvc install                    # vendors the five decks (and forensicgenetics) into vendor/
sh fetch_samples.sh            # public samples into data/, checked by SHA-256
python3 make_data.py           # synthetic traces, references and study table into data/
jennifer run make_reads.j      # 2000 synthetic reads into data/reads.fastq
```

`fetch_samples.sh` downloads `3730.ab1`, `test.fsa` and `fake.ab1` from
Biopython's test suite (`Tests/Abi`, Biopython License Agreement) and
`tree.xml`, the synthetic seven-haplogroup test tree of deck-mitoleaf 0.3.0
(LGPL-3.0-only). The same three ABIF files ship in deck-abif's `testdata/`
with their licence. Everything else is generated, seeded, and contains no
real person's DNA. `make_data.py` needs only Python's standard library.

## Programs

- `sequences.j`: DNA, RNA, protein, frames, motifs, restriction sites and
  FASTA with @deckyard/bioinformatics (slides "One read, four molecules",
  "Frames, motifs and sites", "FASTA"). `jennifer run sequences.j`
- `trace.j`: ABIF metadata, base calls, qualities and a plot of 20 bases of
  the analysed trace to `out/trace.svg` (slides "ABIF", "Base calls",
  "Plotting a trace"). `jennifer run trace.j [file.ab1] [first-base]`;
  `rsvg-convert -w 760 out/trace.svg -o trace.png` made the slide's image.
- `fragments.j`: dyes, raw traces and a naive peak count of a fragment run,
  plot to `out/fragments.svg` (slide "Fragment analysis").
  `jennifer run fragments.j [file.fsa]`
- `make_reads.j`: writes the synthetic FASTQ file. `jennifer run make_reads.j`
- `reads.j`: streaming FASTQ, one-pass QC and trimming with @deckyard/ngs
  (slides "FASTQ", "Quality control", "Trimming"). `jennifer run reads.j`
- `formats.j`: SAM, VCF and BED lines and interval arithmetic (slide "SAM,
  VCF and BED"). `jennifer run formats.j`
- `haplogroups.j`: the mitoLEAF test tree, motifs, back mutations, nearest
  haplogroup and its limits (slides "mitoLEAF", "Nearest is not a
  classification"). `jennifer run haplogroups.j`
- `pipeline.j`: two synthetic traces to trimmed reads, differences against
  the references, nearest haplogroup (slides "A pipeline", "The pipeline's
  run"). `jennifer run pipeline.j`
- `study.j`: a study table from Stata, SPSS or SAS with @deckyard/statfiles
  (slide "Study results"). `jennifer run study.j [file]`
- `errors.j`: malformed and oversized input, by error kind (slides
  "Malformed input" and "Huge input"). `jennifer run errors.j`
- `make_data.py`: writes `data/mito-hvs1.ab1`, `data/mito-hvs2.ab1`,
  `data/refs.fasta` and `data/study.dta`. `python3 make_data.py`
- `fetch_samples.sh`: fetches the public samples. `sh fetch_samples.sh`

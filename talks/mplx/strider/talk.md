---
theme: nordic
ratio: 16:9
transition: slide
---

# From STRidER frequencies to match probabilities

![Jennifer](jennifer-logo.png)

From a STRidER allele-frequency export to a random match probability, with
the `@deckyard/strider` and `@deckyard/forensicgenetics` decks.

November 2026, by [@mplx](https://github.com/mplx).\
Based on **Jennifer 0.26.0**

<!-- notes:
Forensic DNA statistics rest on two things: a profile, and a table that says how
common each part of it is in a reference population. This talk reads such a
table, as published by the STRidER database, converts one population of it and
computes match probabilities and likelihood ratios with it. Every population,
frequency and profile on these slides is invented: STRidER's terms do not allow
its tables to be redistributed, so the examples use a tiny export in the same
shape with made-up numbers. Every output is from a real run.
-->

---

## STR profiles in one slide

| Locus | Genotype | Read as |
| --- | --- | --- |
| D3S1358 | 15/17 | 15 and 17 repeats of a 4-base motif |
| vWA | 17/17 | the same allele from both parents: homozygous |
| TH01 | 6/9.3 | 9.3: nine full repeats and 3 bases of a tenth |

- a short tandem repeat (STR) locus varies in its number of repeats
- one allele from each parent: a genotype is an unordered pair
- a casework kit types about 16 to 24 autosomal loci at once

<!-- notes:
A short tandem repeat is a stretch of DNA where a short motif, usually four
bases, repeats a variable number of times. The allele is named by its repeat
count; a partial repeat gives names like 9.3. Everyone carries two alleles per
locus, one from each parent, and the pair is unordered: 15/17 and 17/15 are the
same genotype. A profile is the list of genotypes across a kit's loci. Our
examples use three loci to stay readable; real profiles use far more.
-->

---

## From frequencies to a match probability

```text
heterozygote ab:   2 pa pb        homozygote aa:   pa^2
profile:           product over all loci
with theta (NRC II 4.2):
  ab: 2 [t + (1-t)pa] [t + (1-t)pb] / [(1+t)(1+2t)]
  aa: [2t + (1-t)pa] [3t + (1-t)pa] / [(1+t)(1+2t)]
```

- **RMP**: the chance that an unrelated person shares the profile
- **LR** for a single-source match: `1 / RMP`
- theta corrects for shared ancestry within a population

<!-- notes:
Under Hardy-Weinberg equilibrium a heterozygote occurs with frequency two p q
and a homozygote with p squared, and independent loci multiply. Real
populations have substructure: people in one group share ancestry, so matches
are more likely than the product rule says. The NRC II recommendation 4.2,
the Balding-Nichols formula, adds the co-ancestry coefficient theta, usually
0.01, or 0.03 for small isolated groups. The likelihood ratio compares "the
stain came from this person" with "it came from an unrelated person".
-->

---

## STRidER and its export

- STRidER: the STR reference database of ENFSI, the European network of
  forensic science institutes, at strider.online
- quality-controlled allele frequencies per country, per continent and for
  the entire database
- **one XML download holds every population**
- its terms of use reserve redistribution: download your own copy

This talk uses a tiny **invented** export in the same shape: populations
NORTHLAND and SOUTHLAND, three loci, made-up numbers.

<!-- notes:
STRidER is the reference database of the European Network of Forensic Science
Institutes. It collects population data sets after a quality check, so a laboratory can
cite one curated source instead of a dozen papers. Its terms allow downloads
for private, non-commercial use and reserve redistribution, which is why
neither the deck nor this talk ships real data. Download the table yourself,
and ask the rights holder before any commercial or published use. The website
is not linked here because the academy only links into the Jennifer project.
-->

---

## The shape of an export

```text
<frequencies created_timestamp="2026-11-01T09:00:00+01:00" ...>
  <marker>
    <name>D3S1358</name>
    <alleles>14, 15, 16, 17, 18</alleles>
    <origin name="Entire Database" n="12000">
      <frequency allele="14">1.20000e-01</frequency>
      ...
    </origin>
    <origin name="NORTHLAND" n="800"> ... </origin>
    <origin name="SOUTHLAND" n="150"> ... </origin>
  </marker>
```

Locus-major: each `<marker>` nests every population as an `<origin>`.

<!-- notes:
The export is organised by locus, not by population. Each marker names its
locus in a child element and lists, for every population that typed it, an
origin with the sample size N in the attribute n and one frequency per allele,
in scientific notation. The alleles list is ignored by the reader. Here
SOUTHLAND, a small invented sample of 150 people, did not type TH01 at all, and
its D3S1358 block has no allele 14: both happen in real exports.
-->

---

## Two decks, one direction

```text
$ jvc add @deckyard/strider && jvc install
installed 2 deck(s):
  ok    @deckyard/strider 0.1.0 -> https://github.com/deckyard/...
  ok    @deckyard/forensicgenetics 0.5.0 -> https://github.com/deckyard/...
```

```jennifer excerpt
import "@deckyard/strider/" as strider;
import "@deckyard/forensicgenetics/" as forensics;
```

- `strider` reads STRidER XML and produces a `forensics.FrequencyDb`
- `forensicgenetics` does the statistics and reads no file format
- another source needs another reader, not a change to the core

<!-- notes:
Both decks are in the public registry, and jvc installs forensicgenetics as a
dependency of the reader. The split is deliberate: the statistics deck knows
nothing about STRidER and takes a FrequencyDb, a plain struct of loci, sample
sizes and allele frequencies. The reader depends on the core, never the other
way round. A table from a paper or another database would get a reader of its
own that produces the same struct.
-->

---

## parse: every population at once

```jennifer excerpt
def t as strider.Table init strider.parse(fs.readString("export.xml"));
io.printf("%s\n", $t.created);
io.printf("%v\n", strider.populations($t));
io.printf("%v\n", strider.loci($t, "SOUTHLAND"));
io.printf("N = %d\n", strider.sampleSize($t, "SOUTHLAND", "vWA"));
io.printf("%v\n", strider.frequencySums($t, "NORTHLAND"));
```

```text
2026-11-01T09:00:00+01:00
["Entire Database", "NORTHLAND", "SOUTHLAND"]
["D3S1358", "vWA"]
N = 150
{"D3S1358": 1.0, "vWA": 1.0, "TH01": 1.0}
```

<!-- notes:
`parse` reads the whole document once and turns it around into a table keyed
by population. The population is chosen afterwards, by its label. Loci are
asked per population, because a small country types fewer loci than the whole
database. `frequencySums` totals every locus of one population; a sound table
sums to about one everywhere. A real download holds 33 populations; use
`allFrequencySums` to audit all of them with a single copy of the table.
-->

---

## Check the sums before you trust a table

| A locus that sums to | Happens when | `toFrequencyDb` |
| --- | --- | --- |
| about 1.0 | the table is sound | converts |
| 0.60 | truncated, or a value misread | **converts silently** |
| 100.00 | the table is in per cent | throws `forensicgenetics` |

```text
parsed, sum 0.60; converted
parsed, sum 100.00; forensicgenetics: locus 'TH01' allele '6':
  frequency must be in (0, 1]
```

<!-- notes:
Conversion validates every locus: a frequency must lie between zero and one,
and a locus may sum to at most 1.05, which leaves room for rounding in the
published figures. A percentage-scaled table is caught that way. A locus that
sums to 0.6 is not: a table may legitimately list only part of a locus, so
the core cannot tell a truncated download from a partial one. Only your check
of the sums catches it, so run it after every new download.
-->

---

## Choose a population, convert

```jennifer excerpt
def south as forensics.FrequencyDb init
    strider.toFrequencyDb($t, "SOUTHLAND", "");
io.printf("%s %v\n", $south.name, forensics.loci($south));
io.printf("%v\n", $south.loci["D3S1358"].alleles);
```

```text
SOUTHLAND ["D3S1358", "vWA"]
{"15": 0.31, "16": 0.29, "17": 0.23, "18": 0.17}
```

- the label travels with the table: `""` keeps the population's own
- **frequencies are kept as published**: no floor, no renormalisation

<!-- notes:
`toFrequencyDb` takes the parsed table, the population label and a name for
the result; an empty name keeps the label. The name ends up in error messages
and reports, so every number can say which dataset produced it. Nothing is
adjusted on the way: the published frequencies and N cross over exactly as the
export states them. That keeps the converted table checkable against the
source and leaves the statistical corrections to the place that applies them.
-->

---

## Rare and missing alleles: 5/(2N), on read

```jennifer excerpt
io.printf("floor %f|prec=4\n",
    forensics.minFrequency($south, "D3S1358"));
for (def a in ["14", "15"]) {
    io.printf("%s: %f|prec=4\n", $a,
        forensics.alleleFrequency($south, "D3S1358", $a));
}
```

```text
floor 0.0167
14: 0.0167
15: 0.3100
```

N = 150 people, 300 alleles: 5 / 300 = 0.0167. Allele 14 is not in the
table; it is scored at the floor, never at zero.

<!-- notes:
A sample of 150 people has seen 300 alleles, so an allele with a true
frequency below about one in three hundred is often simply absent. Scoring it
as zero would make any profile carrying it impossible. NRC II sets a minimum
allele frequency of five over 2N for the locus's own N, and the core applies
it when a frequency is read, not when the table is stored. A listed allele
below the floor is raised to it; one above it is used as published.
-->

---

## A profile and its genotype frequencies

```jennifer excerpt
def stain as forensics.Profile init forensics.profile("stain 1", [
    forensics.genotype("D3S1358", "17", "15"),
    forensics.genotype("vWA", "17", "17"),
    forensics.genotype("TH01", "9.3", "6")]);
for (def locus in forensics.profileLoci($stain)) {
    def g as forensics.Genotype init $stain.loci[$locus];
    io.printf("%s %s/%s %f|prec=4\n", $locus, $g.a, $g.b,
        forensics.genotypeFrequency($north, $g, $th));
}
```

```text
D3S1358 15/17 0.1270
vWA 17/17 0.0886
TH01 6/9.3 0.1424
```

<!-- notes:
`genotype` puts the pair in canonical order, so 17/15 becomes 15/17 and 9.3/6
becomes 6/9.3; alleles are strings, and numeric ones are ordered by repeat
count. `$north` is NORTHLAND converted the same way as SOUTHLAND, and `$th` is
`forensics.THETA_GENERAL`, 0.01. Each line is NRC II 4.2 on the floored
frequencies: the homozygote at vWA is 0.0886 rather than 0.28 squared, 0.0784,
because theta makes a second copy of an allele more likely.
-->

---

## RMP, likelihood ratio, verbal scale

```jennifer excerpt
def rmp as float init
    forensics.randomMatchProbability($north, $stain, $th);
def lr as float init
    forensics.matchLikelihoodRatio($north, $stain, $th);
io.printf("RMP %f|prec=6, LR %f|prec=0, %s\n", $rmp, $lr,
    reporting.verbalEquivalent($lr).label);
```

```text
RMP 0.001603, LR 624, moderately strong support
```

- `reporting` is a sibling module: `"@deckyard/forensicgenetics/reporting.j"`
- a real profile of 20 loci gives an RMP far below this; use
  `log10RandomMatchProbability` once the product could underflow

<!-- notes:
The random match probability is the product of the three genotype
frequencies, and the single-source likelihood ratio is its reciprocal. The
reporting module maps a likelihood ratio onto the ENFSI 2015 verbal scale:
between 100 and 1000 is moderately strong support. With three invented loci
that is all we get; a full kit multiplies twenty such factors. Below 1e-308 a
float cannot hold the product, and `matchLikelihoodRatio` throws rather than
returning infinity, so long panels use the log10 functions.
-->

---

## The population and theta change the answer

| theta | NORTHLAND | Entire Database |
| --- | ---: | ---: |
| 0 (product rule) | 747 | 853 |
| 0.01 (`THETA_GENERAL`) | 624 | 707 |
| 0.03 (`THETA_ISOLATED`) | 452 | 506 |

Same stain, same three loci: the likelihood ratio, run for each cell.

- a result belongs to a profile **and** a chosen reference population
- a larger theta gives a smaller, more conservative LR

<!-- notes:
The table was produced by looping the same call over the three theta constants
and two converted populations. The difference between populations is small
here because the invented numbers are similar; real populations differ more,
and the effect compounds over twenty loci. Which population and which theta
to use is a decision for the laboratory's validated procedure, and the report
must state both. The deck only makes the choice explicit by requiring it.
-->

---

## Missing loci are refused, not skipped

```jennifer excerpt
forensics.randomMatchProbability($south, $stain, $th);     # throws
def used as forensics.Profile init
    forensics.restrict($stain, forensics.commonLoci($south, $stain));
io.printf("%v: LR %f|prec=0\n", forensics.profileLoci($used),
    forensics.matchLikelihoodRatio($south, $used, $th));
```

```text
forensicgenetics: frequency database 'SOUTHLAND' has no locus 'TH01'
["D3S1358", "vWA"]: LR 54
```

<!-- notes:
SOUTHLAND never typed TH01. Silently skipping that locus would make the match
probability larger and the evidence look weaker, with no trace in the output.
So the core throws, with the table's name and the locus. If the narrower comparison is what you want, say so:
`commonLoci` lists the shared loci, `restrict` narrows the profile, and the
report can list exactly which loci were used.
-->

---

## No N, no floor

```jennifer excerpt
def noN as forensics.FrequencyDb init forensics.withLocus(
    forensics.db("no N"), "TH01", 0, {"6": 0.3, "9.3": 0.7});
forensics.alleleFrequency($noN, "TH01", "8");               # throws
```

```text
forensicgenetics: locus 'TH01' allele '8': no frequency and no 5/2N
  floor (the table is missing its sample size)
```

- an `<origin>` without `n` gives N = 0 in the `FrequencyDb`
- listed alleles still work; an unlisted one has nothing to fall back on

<!-- notes:
The floor needs the sample size. If an export states no n for a population,
the reader records zero, which the core reads as "unknown". A listed allele is
then used as published, but an allele the table does not list has neither a
frequency nor a floor, and the core refuses to invent one. Check
`forensics.sampleSize` after converting if an export's N is in doubt. Built by
hand here with `withLocus`, which is what the reader calls for every locus.
-->

---

## Malformed exports and their kinds

| Input | `kind` | Thrown by |
| --- | --- | --- |
| broken XML, a frequency like `n/a` | `runtime` | `parse` |
| no `<marker>`, an allele listed twice | `strider` | `parse` |
| a population the export lacks | `strider` | `toFrequencyDb`, `load` |
| per-cent table, frequency 0 or above 1 | `forensicgenetics` | `toFrequencyDb` |

```text
runtime: toFloat("n/a"): not a valid float
strider: duplicate allele '6' in 'TH01' / 'X'
strider: no such population in the export: 'AUSTRIA'
```

<!-- notes:
Every row was produced by feeding a broken document to the deck. Structural
problems in the export are the reader's own kind, "strider", and name the
locus and population. Malformed XML and unparseable numbers surface with the
kind of the library that found them, "runtime" from the XML decoder and from
convert. Validation of the numbers belongs to the core and throws its kind. A
duplicate allele is an error rather than last-one-wins, because it breaks the
sum.
-->

---

## Unsure of the population? Do not pool

```jennifer excerpt
forensics.matchLikelihoodRatioAcross([$north, $south], [0.5, 0.5],
    $p, $th);
forensics.matchLikelihoodRatio(
    forensics.combineFrequencies([$north, $south], "N+S"), $p, $th);
```

| Two-locus profile | LR |
| --- | ---: |
| NORTHLAND / SOUTHLAND | 88.8 / 53.9 |
| across, weights 0.5 and 0.5 | 67.1 |
| pooled table | 81.7 |

<!-- notes:
If the donor came from one of two populations, the law of total probability
averages the match probabilities, weighted by the prior for each: that is the
Across form. Pooling the tables first averages allele frequencies instead,
weighted by sample size. A mixture of populations has more homozygotes than
pooled frequencies predict, the Wahlund effect, so the error can go either way
per locus. Here the pooled LR is higher than the correct one, which overstates
the evidence. `$p` is the stain restricted to the two shared loci.
-->

---

## What these numbers are not

- **not** the probability that the suspect is innocent: that is the
  prosecutor's fallacy
- **not** for relatives: a brother shares far more; see `kinship.j`
- **not** for mixtures: `forensics.cpi`, `cpe` and `mixture.j`
- **not** a validated casework tool: the decks say so themselves

Use them for research, teaching and cross-checking.

<!-- notes:
A random match probability of one in a thousand does not mean a thousand to
one that the suspect left the stain; it says how surprising the match would be
if someone unrelated had. Relatives need kinship coefficients, mixtures need
other methods, and the forensicgenetics deck has modules for both. Neither
deck has been through the validation a jurisdiction requires for casework
software, and both documentations state that limit plainly.
-->

---

## Read more

- Reader: [deckyard/deck-strider-frequency-converter](https://registry.jennifer-lang.dev/deck/deckyard/strider),
  `@deckyard/strider` in the [registry](https://registry.jennifer-lang.dev/)
- Statistics: [deckyard/deck-forensicgenetics](https://registry.jennifer-lang.dev/deck/deckyard/forensicgenetics),
  `@deckyard/forensicgenetics`
- STRidER itself: strider.online (download, formulae, terms of use)
- This talk: in the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
The reader's documentation explains choosing a dataset and the cost of each
accessor on a real download. The forensicgenetics documentation covers theta,
the frequency floor, kinship, paternity, mixtures and the reporting scale,
with the formulae it follows. Remember the three habits from this talk: check
the sums after every download, name the population and theta in every result,
and let a missing locus be an error rather than a silent omission.
-->

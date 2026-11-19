# STRidER frequencies: the code

The programs behind the slides. They use two community decks,
`@deckyard/strider` (the reader) and `@deckyard/forensicgenetics` (the
statistics), and run with Jennifer 0.26.0. No server is needed.

Setup, once, from this folder:

```sh
jvc install        # reads deck.toml, vendors both decks into vendor/
```

Run every program from this folder, because they open `export.xml` by
relative path. `export.xml` is a small export in the STRidER shape with
**invented** numbers for three made-up populations; it is not real population
data.

- `parse.j`: `strider.parse`, the populations, loci, sample size and
  frequency sums of an export ("parse: every population at once", "Check the
  sums before you trust a table").
  Run: `jennifer run parse.j`
- `convert.j`: one population converted to a `forensics.FrequencyDb`, its
  alleles as published and the 5/(2N) floor for an unlisted allele ("Choose a
  population, convert", "Rare and missing alleles: 5/(2N), on read").
  Run: `jennifer run convert.j`
- `match.j`: genotype frequencies of a three-locus stain, RMP, likelihood
  ratio and verbal scale, then the LR for each theta and two populations
  ("A profile and its genotype frequencies", "RMP, likelihood ratio, verbal
  scale", "The population and theta change the answer").
  Run: `jennifer run match.j`
- `rare.j`: the floor on read, a locus missing from the table refused and the
  explicit `restrict` to common loci, and a table without N
  ("Rare and missing alleles: 5/(2N), on read", "Missing loci are refused, not
  skipped", "No N, no floor").
  Run: `jennifer run rare.j`
- `bad.j`: broken exports and the kind each one throws ("Malformed exports and
  their kinds").
  Run: `jennifer run bad.j`
- `across.j`: a two-population LR with priors versus a pooled table
  ("Unsure of the population? Do not pool").
  Run: `jennifer run across.j`

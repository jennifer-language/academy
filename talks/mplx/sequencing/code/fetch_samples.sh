#!/bin/sh
# Fetch the public sample files into data/ and check their SHA-256:
# three ABIF files from Biopython's test suite (Biopython License
# Agreement) and deck-mitoleaf's synthetic test tree (LGPL-3.0-only).
set -eu
cd "$(dirname "$0")"
mkdir -p data
bio=https://raw.githubusercontent.com/biopython/biopython/master/Tests/Abi
for f in 3730.ab1 test.fsa fake.ab1; do
    curl -sfL -o "data/$f" "$bio/$f"
done
curl -sfL -o data/tree.xml \
    https://raw.githubusercontent.com/deckyard/deck-mitoleaf/0.3.0/testdata/tree.xml
cd data
sha256sum -c <<'SUMS'
e4663e4db40232576ccdda5b878dddb01ef80a3d1b032941ba053146ce53f77b  3730.ab1
3c97441fea6d04af4b3aa32b2752f4802f6d508cb8dafd222bdfd8ebacda3763  test.fsa
86d9ee4daee09fdcd74f8bb53b43cf5a3ed48633816f6d25892c193d99caaea6  fake.ab1
SUMS

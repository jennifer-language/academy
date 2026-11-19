#!/usr/bin/env python3
"""Write the talk's synthetic sample files into data/ (standard library only).

  mito-hvs1.ab1, mito-hvs2.ab1   two made-up Sanger traces (ABIF 1.01)
  refs.fasta                     the made-up reference regions they belong to
  study.dta                      a made-up study table (Stata format 114)

Nothing here is real human data: the reference regions are random bases
with a few positions fixed so that they line up with the deck-mitoleaf
test tree (testdata/tree.xml), which is itself synthetic.
"""
import math
import os
import random
import struct

random.seed(26)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
os.makedirs(OUT, exist_ok=True)


def reference(start, stop, fixed):
    """Random bases for positions start..stop, some of them fixed."""
    seq = [random.choice("ACGT") for _ in range(start, stop + 1)]
    for pos, base in fixed.items():
        for k, b in enumerate(base):
            seq[pos - start + k] = b
    return "".join(seq)


# HVS-II stand-in, positions 1-420: the rCRS bases the tree names at 73, 146
# and 263, and a C-stretch 303-315 interrupted by a T at 310, then a G.
HVS2 = reference(1, 420, {73: "A", 146: "T", 263: "A",
                          303: "CCCCCCCTCCCCCG"})
# HVS-I stand-in, positions 16024-16365: C at 16187 and 16278.
HVS1 = reference(16024, 16365, {16187: "C", 16278: "C"})


def mutate(ref, start, subs, ins_after=None, ins_base=""):
    seq = list(ref)
    for pos, base in subs.items():
        seq[pos - start] = base
    if ins_after is not None:
        seq.insert(ins_after - start + 1, ins_base)
    return "".join(seq)


# The sample: 73G and an extra C in the C-stretch (315.1C) in HVS-II,
# 16278T in HVS-I.
SAMPLE2 = mutate(HVS2, 1, {73: "G"}, 315, "C")
SAMPLE1 = mutate(HVS1, 16024, {16278: "T"})

ORDER = "GATC"          # FWO_: DATA 9..12 hold G, A, T, C
SPACING = 12


def trace(bases, quals):
    """Four analysed channels with one Gaussian peak per base."""
    n = len(bases) * SPACING + 40
    chans = [[0.0] * n for _ in range(4)]
    peaks = []
    for i, (b, q) in enumerate(zip(bases, quals)):
        p = 20 + i * SPACING + random.randint(-1, 1)
        peaks.append(p)
        h = random.uniform(700, 1300) if q >= 20 else random.uniform(150, 400)
        main = ORDER.index(b) if b in ORDER else random.randrange(4)
        for c in range(4):
            height = h if c == main else (h * random.uniform(0.3, 0.8)
                                          if q < 20 else h * 0.03)
            for x in range(max(0, p - 10), min(n, p + 11)):
                chans[c][x] += height * math.exp(-((x - p) ** 2) / 8.0)
    for c in range(4):
        for x in range(n):
            chans[c][x] += random.uniform(0, 15)
    return [[int(v) for v in ch] for ch in chans], peaks


def read_with_ends(sample):
    """Low-quality junk on both ends, as in a real Sanger read."""
    head = "".join(random.choice("ACGTN") for _ in range(18))
    tail = "".join(random.choice("ACGTN") for _ in range(30))
    bases = head + sample + tail
    quals = ([random.randint(2, 12) for _ in head]
             + [random.randint(30, 55) for _ in sample]
             + [random.randint(2, 14) for _ in tail])
    return bases, quals


def abif(path, sample_name, bases, quals):
    chans, peaks = trace(bases, quals)
    tags = []  # (name, number, type, size, data)

    def pstr(s):
        return bytes([len(s)]) + s.encode("ascii")

    for k in range(4):
        tags.append(("DATA", 9 + k, 4, 2,
                     struct.pack(">%dh" % len(chans[k]), *chans[k])))
    tags.append(("Dye#", 1, 4, 2, struct.pack(">h", 4)))
    tags.append(("FWO_", 1, 2, 1, ORDER.encode()))
    tags.append(("MODL", 1, 2, 1, b"SYN "))
    tags.append(("PBAS", 1, 2, 1, bases.encode()))
    tags.append(("PBAS", 2, 2, 1, bases.encode()))
    tags.append(("PCON", 1, 2, 1, bytes(quals)))
    tags.append(("PCON", 2, 2, 1, bytes(quals)))
    tags.append(("PLOC", 1, 4, 2, struct.pack(">%dh" % len(peaks), *peaks)))
    tags.append(("PLOC", 2, 4, 2, struct.pack(">%dh" % len(peaks), *peaks)))
    tags.append(("SMPL", 1, 18, 1, pstr(sample_name)))
    tags.append(("TUBE", 1, 18, 1, pstr("A1")))
    body = b""
    entries = b""
    at = 128
    for name, num, typ, size, data in tags:
        if len(data) > 4:
            off = struct.pack(">I", at)
            body += data
            at += len(data)
        else:
            off = data.ljust(4, b"\0")
        entries += (name.encode() + struct.pack(">IHHII", num, typ, size,
                                                 len(data) // size, len(data))
                    + off + b"\0\0\0\0")
    header = (b"ABIF" + struct.pack(">H", 101) + b"tdir"
              + struct.pack(">IHHIII", 1, 1023, 28, len(tags), 28 * len(tags),
                            at) + b"\0\0\0\0")
    with open(path, "wb") as f:
        f.write(header.ljust(128, b"\0") + body + entries)


def dta(path):
    """A Stata 114 file: one row per (made-up) sample of a study."""
    rows = [
        ("S01", 1, "L0a", 47.2, 3), ("S02", 1, "L0a", 45.9, 3),
        ("S03", 2, "L0b", 44.1, 4), ("S04", 2, "L1a", 46.3, 5),
        ("S05", 1, "L0a1", 41.7, 4), ("S06", 2, "L0", None, 4),
        ("S07", 1, "L1", 43.0, 6), ("S08", 2, "L0a", 48.4, 3),
    ]
    names = ["sample", "region", "hg", "meanq", "ndiff"]
    types = [8, 251, 8, 254, 251]      # str8, byte, str8, float, byte
    fmts = ["%8s", "%8.0g", "%8s", "%9.1f", "%8.0g"]
    lbls = ["", "regionlbl", "", "", ""]
    labels = ["Sample ID", "Collection region", "Nearest haplogroup",
              "Mean Phred quality", "Distance to haplogroup"]

    def fixed(s, n):
        return s.encode("ascii").ljust(n, b"\0")

    out = struct.pack("<BBBBhi", 114, 2, 1, 0, len(names), len(rows))
    out += fixed("Synthetic mtDNA study", 81) + fixed("19 Nov 2026 10:00", 18)
    out += bytes(types)
    out += b"".join(fixed(n, 33) for n in names)
    out += b"\0\0" * (len(names) + 1)
    out += b"".join(fixed(f, 49) for f in fmts)
    out += b"".join(fixed(l, 33) for l in lbls)
    out += b"".join(fixed(l, 81) for l in labels)
    out += b"\0" + b"\0\0\0\0"
    for sid, region, hg, q, nd in rows:
        out += fixed(sid, 8) + struct.pack("<b", region) + fixed(hg, 8)
        out += struct.pack("<f", q) if q is not None else struct.pack(
            "<I", 0x7F000000)
        out += struct.pack("<b", nd)
    texts = [b"north\0", b"south\0"]
    table = struct.pack("<ii", 2, sum(len(t) for t in texts))
    table += struct.pack("<ii", 0, len(texts[0])) + struct.pack("<ii", 1, 2)
    table += b"".join(texts)
    out += struct.pack("<i", len(table)) + fixed("regionlbl", 33) + b"\0" * 3
    out += table
    with open(path, "wb") as f:
        f.write(out)


def main():
    abif(os.path.join(OUT, "mito-hvs2.ab1"), "SYN-HVS2", *read_with_ends(SAMPLE2))
    abif(os.path.join(OUT, "mito-hvs1.ab1"), "SYN-HVS1", *read_with_ends(SAMPLE1))
    with open(os.path.join(OUT, "refs.fasta"), "w") as f:
        f.write(">HVS2 synthetic stand-in, positions 1-420\n")
        f.write("\n".join(HVS2[i:i + 60] for i in range(0, len(HVS2), 60)) + "\n")
        f.write(">HVS1 synthetic stand-in, positions 16024-16365\n")
        f.write("\n".join(HVS1[i:i + 60] for i in range(0, len(HVS1), 60)) + "\n")
    dta(os.path.join(OUT, "study.dta"))


if __name__ == "__main__":
    main()

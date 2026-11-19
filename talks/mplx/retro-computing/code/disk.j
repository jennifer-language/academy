#!/usr/bin/env -S jennifer run
# Format a 1541 disk image, write the maze program and a readme, read
# both back, look at the BAM, the PETSCII names and an undo by value.
# Writes demo.d64 into the current directory.

use io;
use encoding;
use binary;

import "@deckyard/d64/" as d64;

def const BASIC as int init 0x0801;

# 10 PRINT CHR$(205.5+RND(1));:GOTO 10, as the C64 stores it
func maze() {   # loaded at BASIC = 0x0801
    def line as bytes init encoding.fromText("hex", "0a00" + "9920c728"
        + "3230352e35" + "aabb28312929" + "3b3a89203130" + "00");
    def next as int init BASIC + 2 + len($line);   # the next line
    def prg as bytes;
    $prg[] = $next & 0xff;   # low byte first
    $prg[] = $next >> 8;
    for (def b in $line) { $prg[] = $b; }
    return binary.concat($prg, binary.make(2));   # a zero link ends it
}

# A 1541 disk in one slide
io.printf("sectors: %d %d\n", d64.sectorsPerTrack(1), d64.sectorsPerTrack(35));

# Format a disk, list it
def blank as d64.Image init d64.formatDisk("jennifer demo", "jd");
def img as d64.Image init d64.writeProgram($blank, "maze", BASIC, maze());
$img = d64.writeText($img, "readme", d64.FileType.Seq,
    "load\"maze\",8\nrun\n");
io.printf("%s", d64.directoryText($img));
d64.save($img, "demo.d64");

# Reading it back
def again as d64.Image init d64.open("demo.d64");
def info as d64.FileInfo init d64.fileInfo($again, "maze");
io.printf("maze: %d bytes, loads at $%d|base=16, first block %d/%d\n",
    $info.size, $info.loadAddress, $info.chain[0].track,
    $info.chain[0].sector);
def p as d64.Program init d64.readProgram($again, "maze");
io.printf("%s\n", encoding.toText("hex", $p.data));

# The BAM, byte by byte
def bam as bytes init d64.readSector($again, 18, 0);
io.printf("%s\n", encoding.toText("hex", $bam[0..8]));

# Files, the classic way: listFiles
for (def e in d64.listFiles($again)) {
    io.printf("%s %s %d %d/%d\n", $e.name, d64.fileTypeName($e.kind),
        $e.blocks, $e.track, $e.sector);
}

# PETSCII: why names are lower case
io.printf("%s\n", encoding.toText("hex", d64.toPetscii("hello")));
io.printf("%s\n", encoding.toText("hex", d64.toPetscii("Hello")));
io.printf("%s", d64.directoryTextIn($again, d64.Charset.Unshifted));

# Values, not files: undo and errors
io.printf("blank still: %d free\n", d64.blocksFree($blank));
try {
    $img = d64.writeText($img, "README", d64.FileType.Seq, "x");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}

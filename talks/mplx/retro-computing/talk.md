---
theme: obsidian
ratio: 16:9
transition: slide
---

# Retro computing with Jennifer

![Jennifer](jennifer-logo.png)

Commodore™ 1541 disk images and Infocom-style text adventures, byte by byte,
with the `@deckyard/d64` and `@deckyard/zmachine` decks.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
Two pieces of 1980s home computing, taken apart and put back together in
Jennifer. First the floppy disk of the Commodore 64: we format one, write a
BASIC program onto it as raw bytes, and read the allocation map. Then the
Z-machine, the virtual machine Infocom's text adventures ran on, played from a
script. Every output on these slides is from a real run on a laptop, with the
decks' own test game; no copyrighted game or disk is used.
-->

---

## Why retro, why Jennifer

- Old formats are **small and fully documented**: a disk is 174848 bytes, a
  game a few hundred kilobytes
- Everything is `bytes`, `int` and bit masks: `&`, `|`, `>>`, slices
- **Value semantics**: every change returns a new disk or machine, the old one
  is an undo
- Both decks are pure Jennifer, **no capabilities**: they run on
  `jennifer-tiny`, only `open` and `save` touch a file

```sh
jvc add @deckyard/d64
jvc add @deckyard/zmachine
```

<!-- notes:
Retro formats make good teaching material because the whole thing fits in your
head. A 1541 disk image has 683 blocks of 256 bytes, and every byte of the
layout is documented. Jennifer has no pointers and no mutation through
aliases: assigning or passing a value copies it. For an emulator or a disk
editor that is a gift, because keeping the old value costs one variable and
gives you undo. Neither deck asks for network, exec or SQL, so both run on the
small TinyGo build of the interpreter as well.
-->

---

## A 1541 disk in one slide

| Thing | Value |
| --- | --- |
| Tracks | 35 (40 or 42 with speeder DOSes) |
| Sectors per track | 21 outside, 19, 18, 17 inside |
| Block | 256 bytes: 2 bytes link, 254 bytes payload |
| Track 18 | BAM (sector 0) and directory (from sector 1) |
| Free on a blank disk | 664 blocks |

`d64.sectorsPerTrack(1)` is 21, `d64.sectorsPerTrack(35)` is 17.

<!-- notes:
The 1541 writes more sectors on the long outer tracks than on the short inner
ones, so the sector count depends on the track: 21, 19, 18 and 17. Files are
chains of blocks: the first two bytes of each block name the next track and
sector, the other 254 hold data. Track 18 in the middle is reserved for the
block availability map, the BAM, and the directory, which is why a blank disk
shows 664 free blocks and not 683. A D64 file is simply all blocks in order.
-->

---

## Format a disk, list it

```jennifer excerpt
def blank as d64.Image init d64.formatDisk("jennifer demo", "jd");
def img as d64.Image init d64.writeProgram($blank, "maze", BASIC, maze());
$img = d64.writeText($img, "readme", d64.FileType.Seq,
    "load\"maze\",8\nrun\n");
io.printf("%s", d64.directoryText($img));
d64.save($img, "demo.d64");
```

```text
0 "jennifer demo   " jd 2a
   1 "maze"              prg
   1 "readme"            seq
662 blocks free.
```

<!-- notes:
formatDisk does what the command N0:JENNIFER DEMO,JD did on a real drive: an empty BAM,
an empty directory, a name and a two-character disk id. writeProgram and
writeText return a new Image with the file added, and directoryText renders
exactly what LOAD "$",8 followed by LIST shows on the screen. 2a is the DOS
type every 1541 stamps on its disks. save writes the 174848 bytes that any
emulator, such as VICE, opens as drive 8.
-->

---

## A BASIC program is just bytes

```jennifer excerpt
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
```

<!-- notes:
BASIC on the C64 never stores your text. Each line is a link to the next line,
the line number as two bytes, then the text with every keyword squeezed into
one token byte: PRINT is hex 99, CHR$ is c7, RND is bb, GOTO is 89, and even
plus is a token, aa. A zero byte ends the line, a zero link ends the program.
This one-liner is the famous maze: it prints one of two diagonal characters at
random, forever. Load the disk in an emulator, type RUN, and watch it.
-->

---

## Reading it back

```jennifer excerpt
def again as d64.Image init d64.open("demo.d64");
def info as d64.FileInfo init d64.fileInfo($again, "maze");
io.printf("maze: %d bytes, loads at $%d|base=16, first block %d/%d\n",
    $info.size, $info.loadAddress, $info.chain[0].track,
    $info.chain[0].sector);
def p as d64.Program init d64.readProgram($again, "maze");
io.printf("%s\n", encoding.toText("hex", $p.data));
```

```text
maze: 30 bytes, loads at $801, first block 17/0
1b080a009920c7283230352e35aabb283129293b3a89203130000000
```

<!-- notes:
fileInfo follows the block chain and reports what the directory only claims:
the real size in bytes, every block, and for a program its load address, the
first two bytes of the file. readProgram splits those two bytes off. The first
block landed on track 17, sector 0: the drive fills the disk outwards from the
directory track to keep the head close to it. The hex dump is exactly the
program from the slide before, starting with the link 081b, low byte first.
-->

---

## The BAM, byte by byte

```jennifer excerpt
def bam as bytes init d64.readSector($again, 18, 0);
io.printf("%s\n", encoding.toText("hex", $bam[0..8]));
```

```text
1201410015ffff1f
```

| Bytes | Meaning |
| --- | --- |
| `12 01` | the directory starts at track 18, sector 1 |
| `41` | DOS version "A"; a 1541 refuses to write another |
| `15` | track 1 has 21 free blocks |
| `ff ff 1f` | one bit per sector of track 1, 1 = free (21 ones) |

<!-- notes:
readSector returns the 256 raw bytes of any block, without looking at the BAM.
Sector 0 of track 18 is the BAM itself. It starts like a file block with a
link, here to the first directory sector, then the DOS version byte. After it
come four bytes per track: a count of free blocks and a bitmap with one bit
per sector. Track 1 is untouched, so all 21 bits are set. The deck keeps both
in step for you; blocksFree, isFree and allocateSector read and write them.
-->

---

## Files, the classic way

| Call | What it does |
| --- | --- |
| `listFiles(img)` | the directory as `Entry` values |
| `findFiles(img, "?e*")` | the drive's `*` and `?` patterns |
| `readFile` / `readText` | raw bytes, or PETSCII as text |
| `updateFile`, `renameFile`, `deleteFile` | replace, rename, scratch |
| `lockFile(img, name)` | listed with `<`, scratch refuses it |
| `readSector` / `writeSector` | any block, BAM untouched |

```text
maze prg 1 17/0
readme seq 1 17/10
```

<!-- notes:
The deck covers what you did on the drive with DOS commands, and the raw
block access a disk editor needs. The two lines underneath come from
listFiles: name, type, blocks and the first block. The readme starts at
sector 10 of track 17, not sector 1, because of the interleave: the 1541 was
too slow to read the next sector right away, so files skip ten sectors
between blocks. A sector editor in Jennifer is a loop over readSector and
writeSector.
-->

---

## PETSCII: why names are lower case

```jennifer excerpt
d64.toPetscii("hello");   # 48 45 4c 4c 4f: the C64 shows HELLO
d64.toPetscii("Hello");   # c8 45 4c 4c 4f
io.printf("%s", d64.directoryTextIn($again, d64.Charset.Unshifted));
```

```text
0 "JENNIFER DEMO   " jd 2a
   1 "MAZE"              prg
   1 "README"            seq
```

<!-- notes:
The C64 does not speak ASCII. Its PETSCII puts the lower-case letters where
ASCII has capitals, and the power-on character set draws them as capitals. So
the deck follows the petcat convention and swaps case: write names in lower
case and the C64 shows them in upper case. An upper-case ASCII letter becomes
a byte that the power-on set draws as a graphics character. The Unshifted
reading shows the directory the way the screen did after switching on.
-->

---

## Values, not files: undo and errors

```jennifer excerpt
io.printf("blank still: %d free\n", d64.blocksFree($blank));
try {
    $img = d64.writeText($img, "README", d64.FileType.Seq, "x");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
```

```text
blank still: 664 free
d64: a file named "README" is already on this disk
```

<!-- notes:
Every function that changes a disk returns a new Image and leaves its
argument alone. $blank was never touched by the writes that followed, so it
still has 664 free blocks: keeping the previous value is a complete undo,
without copying anything by hand. Every failure is an Error with kind d64.
Names compare without case, as on the drive, so README collides with readme,
and the image in $img stays as it was because the assignment never happened.
-->

---

## The Z-machine

- **Infocom** (Zork, 1980) compiled each game for a virtual machine, then
  wrote one small interpreter per home computer
- Story files `.z3` to `.z8`; **Inform** still compiles new games for it
- The deck is an interpreter: versions 3, 4, 5, 7 and 8, Quetzal saves, undo
- **No terminal of its own:** the host sends lines, reads the output, so a
  game runs in a console, a chat bot or a web page

```jennifer
import "@deckyard/zmachine/" as zmachine;
```

<!-- notes:
Infocom solved the problem of dozens of incompatible home computers with a
virtual machine forty years before it was fashionable. The game was compiled
once; only the small interpreter was written for each machine. The deck is
such an interpreter in Jennifer. It passes the Czech conformance suite in
every version it supports, and Praxix in version 5. The examples use Lantern, a two-room test
game that ships with the deck under its LGPL licence; no Infocom game is
included or needed.
-->

---

## Start a story

```jennifer excerpt
def m as zmachine.Machine init zmachine.open("lantern.z5");
def i as zmachine.Info init zmachine.info($m);
io.printf("version %d, release %d, serial %s\n", $i.version, $i.release,
    $i.serial);
$m = zmachine.run(zmachine.setScreen($m, 60, 24));
io.printf("%s", zmachine.output($m));
```

```text
version 5, release 1, serial 261102
Lantern
A test game for the zmachine deck.
...
```

<!-- notes:
open loads the story file into a Machine, a plain value. info reads the
header: the version, the release and the serial, which is usually the date the
game was compiled. setScreen tells the game how big the screen is, before the
first run, because games read it when they start. run executes instructions
until the game needs something from the outside world, here a line of input.
output returns everything printed to the main window since the last call.
-->

---

## Playing from a script

```jennifer excerpt
for (def line in ["take lamp", "north", "drop lamp", "inventory"]) {
    $m = zmachine.send($m, $line);
    io.printf("%s\n%s", $line, zmachine.output($m));
}
io.printf("status: %s\n", zmachine.upperWindow($m)[0]);
```

```text
>take lamp
Taken.

>north
Garden
An overgrown garden. The hall is to the south.
...
>status:  Garden            Turns: 4
```

<!-- notes:
send answers the pending read with a line and runs the game to its next
wait. Because the host decides where the lines come from, a list of commands
is a test, a walkthrough or a regression check for your own game. upperWindow
returns the rows of the upper window. In version 3 the interpreter draws the
status line with score and moves there; from version 4 on the game draws its
own, and Lantern shows the room and its turns. zmachine.seed makes random
numbers repeat, which a test needs. The status row is 60 columns wide,
trimmed here.
-->

---

## What does the game want?

```jennifer excerpt
while (true) {
    io.printf("%s", zmachine.output($m));
    def w as zmachine.Wait init zmachine.waiting($m);
    if ($w == zmachine.Wait.Quit) { break; }
    if ($w == zmachine.Wait.Save) {
        fs.writeBytes($saveFile, zmachine.saveData($m));
        $m = zmachine.resume($m, true);
        continue;
    }
    # Wait.Restore: zmachine.restore($m, data) or resume($m, false)
    if (io.eof()) { break; }
    $m = zmachine.send($m, io.readLine());   # Wait.Line or Wait.Key
}
```

<!-- notes:
This is the console player from the deck's examples, slightly shortened.
waiting returns an enum: a line, a single key, a save, a restore, or the end
of the game. The interpreter never opens a file itself. When the player types
save, the machine stops with Wait.Save and hands over the save as bytes; the
host stores them wherever it likes, a file, a database row, a chat attachment,
and reports success with resume. That is what makes the same deck work in a
bot.
-->

---

## Save, undo, restore

```text
>take lamp    Taken.
>save         [Wait.Save] quetzal 166 bytes, starts FORM
              Saved.
>north        Garden ...
>undo         Undone.
>restore      [Wait.Restore] restore($m, $q)
              Saved.
```

- **Quetzal**: the standard save format, an IFF file, readable by other
  interpreters
- **Game undo** (`@save_undo`, version 5 and up) is kept inside the machine
- **Host undo** is free: keep the old `Machine` value

<!-- notes:
Quetzal is the save format all modern interpreters share, an IFF container,
which is why it starts with the letters FORM, so saves can move between
interpreters that support it. The transcript is condensed from one run, with
the host's view in brackets. Lantern's undo uses the game's own
save_undo opcode. After the restore the game says Saved. again: it continues
at the save instruction, which now reports a restore, and Lantern does not
tell the two apart. A real game does.
-->

---

## A game in a bot, a test in CI

- **Chat bot:** one `Machine` per chat, or its Quetzal bytes in a store;
  every message is one `send`
- **Web page:** an `httpd` handler sends the form field, returns `output`
- **Your own Inform game:** a list of commands and expected output as a
  `jennifer test` suite
- **Limits:** `setLimit(m, steps)` caps instructions per call (default 50
  million), so a looping story throws instead of hanging

```text
zmachine: zmachine: version 0 stories are not supported (3, 4, 5, 7 and 8 are)
```

<!-- notes:
Because the machine is a value and waits instead of blocking, it fits any
host. A chat bot keeps one machine per chat, or only the save bytes, which
are small. The step limit matters on a server: a broken or hostile story file
cannot spin forever, the call throws and the host carries on. Errors carry
kind zmachine; the line underneath is what loading our D64 file as a story
prints, kind and message, which repeats the deck's name.
-->

---

## Where to find games and disks

- No game ships with the deck; `lantern.z5`, its test game, does
- **Zork I to III** were published by Microsoft™ under the MIT licence
- The **IF Archive** holds hundreds of free Inform games
- For disks: your own old floppies, or new ones made with the d64 deck
- Both decks run on `jennifer-tiny`: a game on a small board

<!-- notes:
Mind the licences. Most Infocom games are still under copyright; the first
three Zork games are the exception, released as open source by Microsoft. The
Interactive Fiction Archive collects free games written by the community over
decades, many of them in Inform. For disk images, the safest material is your
own: everything on these slides was made from scratch, including the maze,
which is a one-liner widely published as a program listing.
-->

---

## Read more

- [deckyard/deck-d64](https://registry.jennifer-lang.dev/deck/deckyard/d64): formatting,
  BAM, PETSCII, the speeder DOS layouts
- [deckyard/deck-zmachine](https://registry.jennifer-lang.dev/deck/deckyard/zmachine):
  playing, saving, the screen, what is supported
- The language: [jennifer-lang.dev](https://jennifer-lang.dev/), more talks
  in the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.27.0, November 2026.

<!-- notes:
Both decks have a manual with guides and a cheatsheet of every function. For
d64, the guides cover sector access, the four BAM layouts of the speeder
DOSes and the two character sets; for zmachine, the screen model, saving and a
list of what is left out. A good next exercise: a program that reads a D64
and prints every BASIC program on it as text, by turning the token bytes back
into keywords.
-->

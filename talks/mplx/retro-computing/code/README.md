# Code for "Retro computing with Jennifer"

The programs behind the slides, for Jennifer 0.26.0. Run everything from
this folder.

## Setup

```sh
jvc update     # reads deck.toml: @deckyard/d64 0.2.0, @deckyard/zmachine 0.1.0 into vendor/
curl -LO https://raw.githubusercontent.com/deckyard/deck-zmachine/0.1.0/testdata/lantern.z5
```

`lantern.z5` is Lantern, the zmachine deck's own two-room test game (LGPL,
like the deck). No Infocom game and no real disk is used. Both decks need
no capability; the programs only read and write files in this folder.

## Programs

| File | Shows (slides) | Run |
| --- | --- | --- |
| `disk.j` | the 1541 layout, format and list, the maze as bytes, reading back, the BAM, `listFiles`, PETSCII, undo by value and the duplicate-name error (3 to 10) | `jennifer run disk.j` (writes `demo.d64`) |
| `story.j` | start Lantern, read its header, play four commands from a list, the status row (12, 13) | `jennifer run story.j` |
| `play.j` | the console player: the `waiting` loop with save and restore to `lantern.z5.qzl` (14) | `jennifer run play.j`, or `printf 'take lamp\nsave\nnorth\nrestore\nlook\n' \| jennifer run play.j` |
| `saves.j` | the save, undo and restore transcript, with the host's view in brackets (15) | `jennifer run saves.j` |
| `limits.j` | a step limit that throws, and loading `demo.d64` as a story (16) | `jennifer run disk.j`, then `jennifer run limits.j` |

`disk.j` writes `demo.d64` (open it in VICE as drive 8, then `LOAD"MAZE",8`
and `RUN`); `play.j` writes `lantern.z5.qzl` when the game saves. Delete
them afterwards.

## Known issue: saving needs zmachine 0.2.0

`@deckyard/zmachine` 0.1.0, the release in the registry, passes its
arguments to `convert.bytesFromString` in the order from before 0.26.0, so
on Jennifer 0.26.0 the game's `save` command throws
`bytesFromString: codec "IFZS" is not supported`. The fix is on the deck's
`main` branch (0.2.0, not yet released). `saves.j` and the save branch of
`play.j` need that version; `story.j`, `limits.j` and play without saving
run on 0.1.0.

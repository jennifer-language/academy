# Code for "Your first command-line tool"

The programs behind the slides, for Jennifer 0.26.0. Run them from this
folder. `tidy.j` and `cases.j` use two decks; fetch them once with
`jvc`, which reads `deck.toml` and fills a
`vendor/` folder here:

```sh
jvc install
```

| File | Slides | How to run |
| --- | --- | --- |
| `argv.j` | os.ARGS | `jennifer run argv.j -n "My Photo.JPG" --case=snake` |
| `streams.j` | stdout and stderr | `jennifer run streams.j > out.txt; echo $?` (prints the message, then `3`) |
| `cases.j` | case conversion | `jennifer run cases.j` (needs `jvc install`) |
| `tidy.j` | all the others | `./tidy.j --help`, then `./tidy.j -n <files>` (needs `jvc install`) |

`tidy.j` renames files, so try it on copies first:

```sh
mkdir photos && touch "photos/Holiday Photo 01.JPG" photos/myBeachDay.jpeg
cd photos
../tidy.j -n *          # dry run: show the new names
../tidy.j *             # rename
../tidy.j -vv -c snake * # back to snake case, with debug logging on stderr
```

To install it as the command `tidy`, link it (a copy would not find `vendor/`):

```sh
chmod +x tidy.j
ln -s "$PWD/tidy.j" ~/.local/bin/tidy
```

Exit codes: `0` all renamed, `1` some files failed, `2` wrong arguments.

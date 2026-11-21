---
theme: nordic
mode: dark
ratio: 16:9
transition: fade
---

# Your first command-line tool

![Jennifer](jennifer-logo.png)

One small, useful program, built step by step: arguments, help, errors,
exit codes, colour, logging, a spinner, and a command you can install.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
This talk is for people who can write a small Jennifer program and now want
to turn one into a real tool: something you type in a terminal, that takes
options, explains itself, fails politely and works with other programs. If
variables, loops and functions are still new, start with the talk Learning
programming with Jennifer first. Every command and every output on these
slides was run with Jennifer 0.26.0; where a line was shortened, the notes
say so.
-->

---

## What we build: `tidy`

```text
$ ls
Holiday Photo 01.JPG   IMG 2041 FINAL.png   myBeachDay.jpeg
$ ../tidy.j *
Holiday Photo 01.JPG -> holiday-photo-01.jpg
IMG 2041 FINAL.png -> img-2041-final.png
myBeachDay.jpeg -> my-beach-day.jpeg
$ ../tidy.j -c snake *
holiday-photo-01.jpg -> holiday_photo_01.jpg
...
```

<!-- notes:
Cameras, phones and colleagues all name files differently: spaces, capital
letters, odd extensions. tidy renames files into one naming style, kebab case
by default, with snake, camel and pascal case as options. It is about 130
lines of Jennifer, and every slide adds one piece of it. The files live in a
folder called photos and the program one level up, which is why it is called
as dot dot slash tidy dot j. The ls output was put on one line to save space.
-->

---

## A program sees its words: `os.ARGS`

```jennifer
use io;
use os;

for (def i in 0..len(os.ARGS)) {
    io.printf("%d: %s\n", $i, os.ARGS[$i]);
}
```

```text
$ jennifer run argv.j -n "My Photo.JPG" --case=snake
0: argv.j
1: -n
2: My Photo.JPG
3: --case=snake
```

<!-- notes:
Everything you type after the program's name reaches it as a list of
strings, os.ARGS. Element zero is the program itself, the rest are the
arguments, already split by the shell. The quotes kept My Photo.JPG together
as one argument; without them it would be two. You could read this list by
hand, but then you would also have to handle help, typos and missing values
yourself. That is what the args module is for.
-->

---

## Describe the options, let `args` parse

```jennifer excerpt
import "args.j" as args;

func buildParser() {
    def p as args.Parser init args.parser("tidy", "rename files tidily");
    $p = args.flag($p, "case", "c", "kebab", "naming style");
    $p = args.choices($p, ["kebab", "snake", "camel", "pascal"]);
    $p = args.boolFlag($p, "dry-run", "n", "only show the new names");
    $p = args.countFlag($p, "verbose", "v", "log more (-v, -vv)");
    $p = args.positionalList1($p, "files", "the files to rename");
    return args.version($p, "tidy 1.0.0");
}
```

<!-- notes:
Instead of reading os.ARGS yourself, you describe what the tool accepts. A
flag has a long name, a one-letter short name, a default and a help text.
choices limits the flag added just before it to a fixed set. A bool flag is
on or off, a count flag counts how often it was given, so dash v v is two.
positionalList1 means one or more file names. Each builder returns a new
parser, so you assign it back every time.
-->

---

## `--help` comes for free

```text
$ ../tidy.j --help
Usage: tidy [options] files [files ...]
rename files tidily
Positional arguments:
  files    the files to rename
Options:
  -h, --help    show this help and exit
  -c, --case CASE    naming style (one of: kebab, snake, camel, pascal)
                     (default: kebab)
  -n, --dry-run    only show the new names
  -v, --verbose    log more (-v, -vv)
```

<!-- notes:
Because the parser knows every option, it can explain them. Dash h and dash
dash help are built in, and dash dash version appears because we called
args.version. The help texts you wrote when describing the options are what
the user reads here, so write them for a stranger. To fit the slide, the
blank lines and the version line are left out, and one long line is wrapped
after the list of choices; the program prints it as one line.
-->

---

## Reading the answers

```jennifer excerpt
if ($r.done) {
    io.printf("%s\n", $r.helpText);
    exit OK;
}
def style as string init args.asString($r, "case");
def dryRun as bool init args.asBool($r, "dry-run");
def verbose as int init args.count($r, "verbose");
def files as list of string init args.asList($r, "files");
```

<!-- notes:
args.parse reads the arguments and returns a Result. When the user asked for
help or the version, done is true and helpText holds the text: print it and
stop with success. Otherwise you ask the result for each value by name, with
the accessor for its type: asString for text, asBool for a switch, count for a
counted flag and asList for the files. From here on the program never looks
at os.ARGS again: it works with named, typed values.
-->

---

## Catching the user's mistake

```jennifer excerpt
def r as args.Result init args.Result{};
try {
    $r = args.parse(buildParser(), os.ARGS);
} catch (e) {
    if ($e.kind != "args") {
        throw $e;
    }
    io.eprintf("tidy: %s\n", $e.message);
    io.eprintf("try 'tidy --help'\n");
    exit USAGE;
}
```

<!-- notes:
An unknown flag, a missing value or a value outside the choices makes
args.parse throw an error of kind args. We catch it, print the message to
standard error with the program's name in front, add a hint, and stop with the
usage exit code. Errors of any other kind are not ours to explain, so we throw
them on unchanged. Check the kind, never the wording of the message.
-->

---

## When the user types it wrong

```text
$ ../tidy.j
tidy: args: positional files needs at least one value
try 'tidy --help'
$ ../tidy.j --case shouty x.jpg
tidy: args: argument --case: 'shouty' is not one of kebab, snake, camel, pascal
try 'tidy --help'
$ ../tidy.j --colour *
tidy: args: unknown flag --colour
try 'tidy --help'
$ ../tidy.j -c
tidy: args: flag -c needs a value
try 'tidy --help'
```

<!-- notes:
A friendly error says three things: which program is talking, what exactly
was wrong, and what to do next. The messages come from the args module, our
program only puts tidy in front and adds the hint about help. Notice what is
missing: no stack trace, no line number in our source. Those help the
programmer, not the person who typed a flag wrong. All four end the program
with exit code 2.
-->

---

## Exit codes: the answer for scripts

| Code | Meaning in `tidy` | Constant |
| --- | --- | --- |
| `0` | everything worked | `OK` |
| `1` | some files could not be renamed | `FAILED` |
| `2` | wrong arguments, nothing was done | `USAGE` |

```text
$ ../tidy.j gone.jpg 2>/dev/null; echo $?
1
$ ../tidy.j -c camel * >/dev/null && echo fine || echo "failed: $?"
failed: 1
```

<!-- notes:
Every program ends with a number. Zero means success, anything else means
some kind of failure, and the shell keeps the number in dollar question mark.
Scripts rely on it: and-and runs the next command only after a success. Two
is the usual code for wrong usage. Give each code a named constant and write
exit OK rather than exit 0, so the reader knows what each one means. The
second run failed because a file name was already taken; we meet that case
soon.
-->

---

## stdout for results, stderr for people

```jennifer
use io;

io.printf("a result, for the next program\n");
io.eprintf("a message, for the human\n");
exit 3;
```

```text
$ jennifer run streams.j > out.txt; echo $?
a message, for the human
3
$ cat out.txt
a result, for the next program
```

<!-- notes:
A program has two output channels. Standard output, io.printf, is for the
result: what another program or a file should receive. Standard error,
io.eprintf, is for messages to the person at the keyboard: errors, progress,
logs. When the user redirects the output into a file, the messages still
appear on the screen, and the file stays clean. In tidy, the list of renames
goes to stdout, everything else to stderr.
-->

---

## Borrowing code: two decks

```text
$ jvc init tidy
created ./deck.toml for deck tidy
$ jvc add @mplx/texttransform "^0.3.0"
added @mplx/texttransform ^0.3.0 to requirements
$ jvc add @mplx/clispinner "^0.2.0"
added @mplx/clispinner ^0.2.0 to requirements
$ jvc install
installed 2 deck(s):
  ok    @mplx/clispinner 0.2.0 -> https://github.com/mplx/deck-clispinner.git
  ok    @mplx/texttransform 0.3.0 -> https://github.com/mplx/deck-texttransform.git
```

<!-- notes:
Jennifer ships modules like args, ansi and log. Other people's code comes as
decks, installed with jvc from the registry. jvc init writes a deck.toml for
the project, jvc add records a deck and its allowed versions, and jvc install
copies the deck's source into a vendor folder next to the program. A few lines
of the install output were left out. Imports then read import @mplx/texttransform
with a slash at the end.
-->

---

## Case conversion with `@mplx/texttransform`

```jennifer
use io;
import "@mplx/texttransform/" as texttransform;

def name as string init "Holiday Photo 01";
for (def style in ["kebab", "snake", "camel", "pascal", "constant"]) {
    io.printf("%s|pad=9 %s\n", $style, texttransform.toCase($name, $style));
}
```

```text
kebab     holiday-photo-01
snake     holiday_photo_01
camel     holidayPhoto01
pascal    HolidayPhoto01
constant  HOLIDAY_PHOTO_01
```

<!-- notes:
toCase splits a text into words, at spaces, dashes, underscores and at the
change from a small to a capital letter, and joins them again in the style
you ask for. The deck can do more: texttransform.t applies a whole recipe
separated by bars, such as trim, fold the accents away, then kebab case. The pad modifier in printf
makes the first column nine characters wide. An unknown style throws an error
of kind texttransform.
-->

---

## The new name

```jennifer excerpt
func newName(file as string, style as string) {
    def stem as string init texttransform.toCase(path.stem($file), $style);
    def ext as string init strings.lower(path.ext($file));
    return path.join(path.dir($file), $stem + $ext);
}
```

| Call | For `photos/IMG 2041.JPG` |
| --- | --- |
| `path.dir` | `photos` |
| `path.stem` | `IMG 2041` |
| `path.ext` | `.JPG` |

<!-- notes:
A file name has parts, and only one of them should change its style. The
path library splits a path for us: the directory, the stem, which is the
name without its extension, and the extension with its dot. We convert the
stem, write the extension in small letters, and put the pieces back together
with path.join. Never cut paths apart by hand with string slices: the path
library knows the corner cases.
-->

---

## Look before you leap

```jennifer excerpt
func plan(file as string, style as string) {
    if (not fs.isFile($file)) {
        return Step{file: $file, target: "", problem: "not a file"};
    }
    def target as string init newName($file, $style);
    return Step{file: $file, target: $target, problem: ""};
}
```

`fs.rename(old, new)` **replaces** an existing file at `new`, silently.

<!-- notes:
Before touching anything, tidy checks every argument and records a plan
step: the file, its new name, and a problem if there is one. A typo on the
command line becomes not a file instead of a crash. The warning below the
code matters most. fs.rename replaces a file that already has the new name,
without asking, the same as mv on Linux. A rename tool must check that
itself, or it destroys photos.
-->

---

## The bug I found writing this talk

```text
$ ls
My Beach Day.jpeg   my-beach-day.jpeg
$ ../tidy.j -c camel *        # first version: one file is gone
```

```jennifer excerpt
if (maps.has($taken, $s.target) or fs.exists($s.target)) {
    log.error($lg, "exists", {"file": $s.file, "target": $s.target});
    $failures = $failures + 1;
    continue;
}
$taken[$s.target] = true;
```

```text
my-beach-day.jpeg -> myBeachDay.jpeg
time=... level=error msg=exists file="My Beach Day.jpeg" target=myBeachDay.jpeg
```

<!-- notes:
The first version only checked whether the new name existed on disk during
planning. Two different files, My Beach Day and my-beach-day, both become
myBeachDay in camel case. Neither name existed at planning time, so the
second rename replaced the first file and the tool even said success. The fix
remembers every name it has handed out in a map and checks the disk again
right before renaming. The timestamp is shortened here.
-->

---

## Dry run first

```text
$ ../tidy.j -n *
Holiday Photo 01.JPG -> holiday-photo-01.jpg
IMG 2041 FINAL.png -> img-2041-final.png
myBeachDay.jpeg -> my-beach-day.jpeg
```

```jennifer excerpt
if (not $dryRun) {
    try {
        fs.rename($s.file, $s.target);
    } catch (e) {
        ...
    }
}
io.printf("%s -> %s\n", $s.file, ansi.green($s.target));
```

<!-- notes:
Any tool that changes or deletes files should have a way to say what it
would do, without doing it. Dash n, or dash dash dry run, runs every check and
prints every new name, and only skips the rename itself. Users try it first,
and you will use it yourself while developing. Afterwards the folder still
holds the three files under their old names.
-->

---

## One bad file is not the end

```jennifer excerpt
try {
    fs.rename($s.file, $s.target);
} catch (e) {
    def why as string init $e.message;
    log.error($lg, "rename failed", {"file": $s.file, "why": $why});
    $failures = $failures + 1;
    continue;
}
```

```text
$ ../tidy.j "ro/Bad Name.txt"; echo $?
time=... level=error msg="rename failed" file="ro/Bad Name.txt"
  why="fs.rename: ro/Bad Name.txt -> ro/bad-name.txt: rename ...:
  permission denied"
1
```

<!-- notes:
A rename can still fail: the folder may be read-only, or the disk full.
Instead of stopping at the first problem, tidy catches the error, reports it
with the file's name, counts it and carries on with the next file. At the end
the count decides the exit code: one if anything failed. The output was run
on a folder without write permission; it is wrapped over three lines and
shortened where the dots are.
-->

---

## Colour with `ansi`, and when it stays off

```jennifer excerpt
io.printf("%s -> %s\n", $s.file, ansi.green($s.target));
```

| Situation | Colour |
| --- | --- |
| stdout is a terminal | on |
| stdout goes to a pipe or a file | off |
| `NO_COLOR` is set (to anything) | off, always |
| `FORCE_COLOR` is set | on, even in a pipe |

<!-- notes:
Colour helps the eye, but escape codes in a file or in another program's
input are garbage. The ansi module checks for you, on every call: colour only
when standard output is a terminal, never when the user set NO_COLOR, and
always when they set FORCE_COLOR. We checked all four cases with the real
program. One detail: the check looks at stdout, so a coloured message on
stderr also loses its colour when stdout is redirected.
-->

---

## Logging with levels

```jennifer excerpt
def level as string init logLevel($verbose);
def lg as log.Logger init log.toStderr("logfmt", $level);
log.info($lg, "planned", {"files": "{$total}", "case": $style});
```

```text
$ ../tidy.j -vv -n * >/dev/null
time=... level=info msg=planned files=4 case=kebab
time=... level=debug msg="already tidy" file=holiday-photo-01.jpg
time=... level=error msg=exists file="My Beach Day.jpeg" target=...
time=... level=info msg=done renamed=0 failed=1
```

<!-- notes:
Not every message is for every run. A logger has a level: at warn it shows
warnings and errors only, dash v lowers it to info, dash v v to debug, and
logLevel turns the count into that name. log.toStderr keeps the log away from
the results. Logfmt writes key equals value pairs that people can read and
tools can search. Timestamps and one target are shortened, and two of the
three debug lines are left out.
-->

---

## A spinner while it works

```jennifer excerpt
import "@mplx/clispinner/" as spinner;

def opts as spinner.Options init spinner.options("dots", "checking");
def sp as spinner.Spinner init spinner.startSpinner($opts);
for (def file in $files) {
    $sp = spinner.statusSpinner($sp, $file);
    $steps[] = plan($file, $style);
}
spinner.removeSpinner($sp);
```

Print nothing while it spins: it owns the line.

<!-- notes:
On a slow network share, checking thousands of photos takes a while, and a
silent terminal looks frozen. The clispinner deck animates in its own task on
stderr, while the loop shows the current file next to it. Off a terminal it
draws nothing. Our first version printed while it spun, and the rename lines
landed in the middle of the animation. So tidy plans with the spinner, removes
it, and only then prints.
-->

---

## Make it a command

```text
$ head -1 tidy.j
#!/usr/bin/env -S jennifer run
$ chmod +x tidy.j
$ ln -s "$PWD/tidy.j" ~/.local/bin/tidy
$ tidy --version
tidy 1.0.0
```

A copy of `tidy.j` alone fails: it needs `vendor/` next to its real path.

<!-- notes:
The first line, the shebang, tells the system to run the file with
jennifer run. chmod plus x makes it executable. A symbolic link in a folder on
your PATH, often dot local slash bin, gives it a short name: tidy, without
the extension. We link instead of copying because Jennifer looks for the
vendor folder beside the real file; a lone copy stops with an error that says
it needs a vendor directory.
-->

---

## The checklist

- read arguments with `args`: help, version and errors for free
- check input before acting, and never overwrite silently
- friendly errors on stderr: who, what, what next
- exit codes `0`, `1`, `2` as named constants
- results on stdout, logs and spinners on stderr
- a dry run for anything that changes files
- colour and spinners only on a terminal; respect `NO_COLOR`
- shebang, `chmod +x`, a link on your `PATH`

<!-- notes:
These eight points make the difference between a script that works for you
and a tool other people can trust. None of them needs much code: tidy is
about 130 lines, and most of those are checks and messages, not renaming.
Take a small chore of your own, a converter, a counter, a cleaner, and build
it the same way. The full program is in the code folder that comes with this
talk.
-->

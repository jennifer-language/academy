---
theme: meridian
ratio: 16:9
transition: fade
---

# Vibecoding with Jennifer

![Jennifer](jennifer-logo.png)

Set up an AI coding assistant that writes Jennifer which really runs: the
language reference, one instruction file, and a check loop.

by [@mplx](https://github.com/mplx)

<!-- notes:
This talk is not about writing code. It is about setting up your computer so
that an AI assistant can write Jennifer for you, and so that what it writes
actually runs. We set up the project folder, the editor and the assistant, and
then watch the assistant fix its own mistakes. You need no programming
experience, only a terminal and an editor you like.
-->

---

## What vibecoding means

- You say what you want, in plain words
- The assistant writes the code and runs it
- You look at the result and say what to change

What you need:

| Piece | Here |
| --- | --- |
| The language | `jennifer`, installed |
| An editor | VS Code, or none at all |
| An assistant | Claude Code, or another one |
| The rule book | `JENNIFER.md` |

<!-- notes:
Vibecoding means you describe the program and the assistant does the typing.
You stay the one who decides: you read what it made, run it, and ask for
changes. Four pieces are needed. The interpreter runs the code, the editor shows
it, the assistant writes it, and JENNIFER.md teaches the assistant the language.
The last piece is the one people forget, and it matters most.
-->

---

## The assistant has never seen Jennifer

Asked for "say hello to three names", with no help:

```jennifer excerpt
names = ["Ada", "Linus", "Grace"]
for name in names {
    print("Hello, " + name)
}
```

```text
$ jennifer run guess.j
guess.j: parse error at ~/vibe/guess.j:1:7: expected SEMI to
terminate statement, got ASSIGN ("=")
```

<!-- notes:
Jennifer is new, so it was not in the texts the assistant learned from. When it
does not know a language, it guesses, and the guess looks like Python or
JavaScript. The interpreter refuses it at once. The output is real; only the
path is shortened. Nothing is wrong with the assistant or with Jennifer: the
assistant simply has not been told the rules yet.
-->

---

## A better guess is still a guess

Told "it is a bit like PHP", it gets closer:

```jennifer excerpt
use io;

def names = ["Ada", "Linus", "Grace"];
foreach ($names as $name) {
    io.println("Hello, $name");
}
```

```text
guess2.j: parse error at ~/vibe/guess2.j:3:11: expected AS after
variable name, got ASSIGN ("=")
```

<!-- notes:
With a hint, the code looks much more like Jennifer: the dollar signs, the use
line, the semicolons. It still fails on the third line, and behind it wait two
more mistakes: Jennifer has no foreach and no io.println. Hints do not help
much. The assistant needs the real rules, written down, every time it starts.
That is what JENNIFER.md is for.
-->

---

## JENNIFER.md: the rule book

- One Markdown file: the whole language, written for assistants
- Starts with "the 10 rules that trip people up"
- Ships with the interpreter, matching its version:

| Installed with | JENNIFER.md is at |
| --- | --- |
| Arch, Debian, Docker | `/usr/share/doc/jennifer/JENNIFER.md` |
| Homebrew | `$(brew --prefix)/share/doc/jennifer/` |
| Windows installer | beside `jennifer.exe` |

<!-- notes:
JENNIFER.md is a single file that describes the whole language for an assistant
that knows nothing about it: syntax, types, every library, and the ten rules
where guesses go wrong most often. Every package installs a copy built from the
same commit as the interpreter, so the two always agree. You copy it into your
project; the assistant reads it before writing code.
-->

---

## The project folder

```text
hello/
  JENNIFER.md     the language, copied from the install
  AGENTS.md       how to work in this project
  CLAUDE.md       one line: @AGENTS.md
  hello.j         your program
```

```sh
mkdir hello && cd hello
cp /usr/share/doc/jennifer/JENNIFER.md .
```

<!-- notes:
Make one folder per project and copy JENNIFER.md into it. Next to it go two
small instruction files. AGENTS.md says how to work here; many assistants look
for a file with that name. CLAUDE.md is the name Claude Code looks for, and its
single line pulls in AGENTS.md, so you keep one set of instructions for every
assistant. The code folder of this talk has both files ready.
-->

---

## AGENTS.md: the house rules

```markdown
This project is written in Jennifer, a language you have not
seen in training. Read JENNIFER.md before writing any .j code,
and first follow its sync steps (compare its last line with
`jennifer version`).

After every change to a .j file:
1. jennifer fmt -w <file>
2. jennifer lint <file>, and fix every warning
3. jennifer run <file>, or jennifer test <file>_test.j

Never guess a library function: look it up in JENNIFER.md.
If lint says a function does not exist, it does not.
```

<!-- notes:
Keep this file short, the assistant reads it at the start of every session.
Three things matter. It must read JENNIFER.md before it writes code. It must
check its own work after every change. And it must look up library functions
instead of inventing them, because inventing them is the most common mistake.
Add your own rules below, like the style you prefer.
-->

---

## Keeping the rule book current

The last line of JENNIFER.md records the version it matches:

```text
<!-- jennifer-md-synced-for: 0.26.0 -->
```

- A fresh copy has no such line yet
- The assistant compares it with `jennifer version`
- Different? It copies the installed file again and updates the line

<!-- notes:
When you upgrade Jennifer, your old copy of JENNIFER.md describes the old
version, and the assistant would write code for it. The file carries its own
instructions for this: the assistant compares the last line with jennifer
version, and if they differ it copies the new file from the install and stamps
the line again. You do not have to remember it; AGENTS.md tells it to check.
-->

---

## The check loop

| Command | Catches |
| --- | --- |
| `jennifer fmt -w f.j` | layout; rewrites the file in the standard style |
| `jennifer lint f.j` | syntax errors, unknown functions, likely bugs |
| `jennifer run f.j` | what the program really does |
| `jennifer test f_test.j` | whether it still does what it should |

The assistant runs these itself, reads the output, and fixes the code.

<!-- notes:
This loop is the heart of vibecoding with a young language. The assistant will
make mistakes; what matters is that it notices them before you do. Lint is the
most useful step: it knows every library function and says when one does not
exist, often with the right name. An assistant that may run these commands
fixes most of its own errors without asking you.
-->

---

## Claude Code in the terminal

```sh
curl -fsSL https://claude.ai/install.sh | bash   # install
cd hello
claude                                           # start, sign in once
```

- Reads `CLAUDE.md` (and with it `AGENTS.md`) at every start
- Edits files and runs commands, asking before each one
- Works with a Claude subscription or an API key

<!-- notes:
Claude Code is an assistant that lives in the terminal. Install it once, go to
your project folder and type claude. The first start asks you to sign in. From
then on it reads CLAUDE.md, which pulls in AGENTS.md, so it knows the house
rules before you say a word. It asks before it changes a file or runs a
command, until you allow it more.
-->

---

## Let it run the checks without asking

`.claude/settings.json` in the project:

```json
{
  "permissions": {
    "allow": [
      "Bash(jennifer fmt:*)",
      "Bash(jennifer lint:*)",
      "Bash(jennifer run:*)",
      "Bash(jennifer test:*)"
    ]
  }
}
```

<!-- notes:
Asking for every lint run gets tiring fast, so allow the four check commands
for this project. Everything else still needs your yes, including deleting
files or running other programs. Allow only what you would let a new colleague
do unsupervised. The code folder has this file as claude-settings.json; copy it
to .claude/settings.json in your project.
-->

---

## VS Code: two extensions

1. **Jennifer** syntax highlighting, from the Jennifer repository
   (see the talk *Syntax highlighting for Jennifer*)
2. **An assistant**, from the Extensions view:
   - *Claude Code*: the same assistant, in a side panel
   - *GitHub Copilot*, or another one you like

Open the project folder (File, Open Folder), not a single file.

<!-- notes:
VS Code is one comfortable way to watch the assistant work. The first
extension colours Jennifer code, so you can read what was written; the
separate talk shows how to install it in every editor. The second is the
assistant itself. Always open the whole folder, so the assistant finds
JENNIFER.md and the instruction files beside your code.
-->

---

## VS Code: point the assistant at the rules

| Assistant | Reads |
| --- | --- |
| Claude Code extension | `CLAUDE.md`, as in the terminal |
| GitHub Copilot | `.github/copilot-instructions.md` (copy AGENTS.md there), recent versions also `AGENTS.md` |
| Others | usually `AGENTS.md`; otherwise paste "read AGENTS.md first" |

Allow the integrated terminal: the check loop runs there.

<!-- notes:
Every assistant has a file it reads by itself at the start. If yours does not
know AGENTS.md, copy the same text to the file it does read, or start each
chat with: read AGENTS.md first. The tools change their names and menus
often, so check their own documentation; the idea stays the same everywhere.
Give it the terminal, or it cannot run the check loop.
-->

---

## The first request

> Write wordcount.j: read sample.txt and print how many words
> it holds. Run the check loop until it is clean.

- One small program at a time
- Say which files to read and write
- Ask for the check loop, even if AGENTS.md says it already

<!-- notes:
Ask for something small and concrete. Name the files, say what should come out,
and remind it of the check loop. Big wishes, like a whole web shop in one
request, give big piles of code nobody has checked. Small steps give you a
program you understand after each one. When it works, ask for the next small
change.
-->

---

## The loop at work: first try

```jennifer excerpt
for (def word in strings.fields($text)) {
    $count++;
}
io.println("{$count} words");
```

```text
$ jennifer lint wordcount.j
~/vibe/wordcount.j:8:12: error: unexpected token PLUS ("+")
in expression [L002]
      $count++;
```

<!-- notes:
Even with JENNIFER.md, the first try had three mistakes from other languages.
Jennifer has no plus plus; you write count equals count plus one. Lint stops at
this syntax error first. The assistant reads the message, looks up the rule in
JENNIFER.md, rule 8 of the ten, and fixes the line. Then it runs lint again.
-->

---

## The loop at work: unknown functions

```text
$ jennifer lint wordcount.j
~/vibe/wordcount.j:7:18: warning: function `strings.fields`
does not exist [L114]
~/vibe/wordcount.j:10:1: warning: function `io.println` does
not exist - did you mean `io.printf`? [L114]
```

- `strings.fields` is Go: it uses `regex.split` instead
- `io.println`: lint names the right function

<!-- notes:
The second lint run finds two invented functions. strings.fields exists in Go,
not in Jennifer, so the assistant looks up the strings and regex libraries in
JENNIFER.md and splits on whitespace with regex.split. For io.println, lint
even suggests the right name. Without the check loop, you would have found
these by running the program, one at a time.
-->

---

## The loop at work: clean

```jennifer
use io;
use fs;
use regex;

def text as string init fs.readString("sample.txt");
def count as int init 0;
for (def word in regex.split('\s+', $text)) {
    if ($word != "") {
        $count = $count + 1;
    }
}
io.printf("{$count} words\n");
```

`jennifer run wordcount.j` prints `8 words`.

<!-- notes:
After two rounds the program is clean: fmt has nothing to change, lint is
silent, and it prints the right answer for the sample file. The assistant did
all of that without you. Your part comes now: read the program, check that the
answer is right, and decide what comes next. This is the version in the code
folder.
-->

---

## Your part: read and judge

- Read every program before you keep it; ask "explain this line"
- Check the answer against something you know
- Ask for a test file, then `jennifer test` guards later changes
- Unsure? Ask it to make the change smaller

<!-- notes:
Clean is not the same as correct. The assistant can write a program that runs
and gives the wrong answer, so compare the result with a case you can work out
by hand. Ask it to explain any line you do not follow; that is how you learn
Jennifer on the way. A test file keeps the program honest when you change it
later.
-->

---

## Safety

- The assistant sends your code to its provider: no passwords or keys in files
- Use an empty project folder, not your home directory
- Allow only the check commands; read before you say yes to the rest
- Keep the project in git, so any change can be undone

<!-- notes:
An assistant that may run commands can also delete things, so give it a folder
of its own and say yes only to what you understand. Whatever it reads leaves
your computer, so secrets never go into the project. Put the folder under git
from the start: if the assistant makes a mess, one command brings back the last
good state.
-->

---

## When it goes wrong

| What you see | What to do |
| --- | --- |
| Code that looks like Python | It skipped JENNIFER.md: "read JENNIFER.md first" |
| `pragma` or "not defined" errors after an upgrade | Let it sync JENNIFER.md again |
| The same error over and over | Stop it; ask it to explain the error first |
| It edits files you did not mention | Say which files it may touch |

<!-- notes:
Most trouble has one of these four causes. The assistant forgot the rule book,
the rule book is older than the interpreter, it is stuck in a loop of small
guesses, or it is doing more than you asked. In each case, stop it and say so
plainly. A fresh session with a clear, small request often beats a long one
that went astray.
-->

---

## Where to go next

- *Syntax highlighting for Jennifer*, *The 10 traps of Jennifer*, *Learning programming
  with Jennifer*, in the [Jennifer Academy](https://academy.jennifer-lang.dev/)
- The language: [docs.jennifer-lang.dev](https://docs.jennifer-lang.dev/)
- `JENNIFER.md` itself: [github.com/jennifer-language/jennifer](https://github.com/jennifer-language/jennifer)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
The syntax highlighting talk sets up your editor for every language file we
ship. The 10 traps talk explains the mistakes that lint catches, so you
understand the fixes the assistant makes. And if you want to read Jennifer
yourself, Learning programming with Jennifer starts from zero. The rule book
is in the Jennifer repository, next to the interpreter.
-->

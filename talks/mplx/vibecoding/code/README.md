# Code for "Vibecoding with Jennifer"

A starting point for a project an AI assistant works in, for Jennifer
0.26.0. Copy this folder, then add the language reference that came with
your interpreter:

```sh
cp /usr/share/doc/jennifer/JENNIFER.md .
mkdir -p .claude && cp claude-settings.json .claude/settings.json
```

On Homebrew the reference is in `$(brew --prefix)/share/doc/jennifer/`, on
Windows beside `jennifer.exe`.

| File | Slides | What it is |
| --- | --- | --- |
| `AGENTS.md` | AGENTS.md: the house rules | the instructions every assistant reads |
| `CLAUDE.md` | The project folder | one line that pulls `AGENTS.md` into Claude Code |
| `claude-settings.json` | Let it run the checks without asking | copy to `.claude/settings.json` |
| `hello.j` | The assistant has never seen Jennifer | what the two guesses should have been: `jennifer run hello.j` |
| `wordcount.j` | The loop at work: clean | `jennifer run wordcount.j` (prints `8 words`) |
| `sample.txt` | | the text `wordcount.j` reads |

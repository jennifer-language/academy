---
theme: meridian
ratio: 16:9
transition: fade
---

# Syntax highlighting for Jennifer

![Jennifer](jennifer-logo.png)

Colour for `.j` files in Vim™, Neovim™, VS Code™, Sublime Text™, JetBrains™ IDEs,
`bat`, web pages and self-hosted forges.

by [@mplx](https://github.com/mplx)

<!-- notes:
Code is easier to read when variables, strings, comments and keywords each have
their own colour. Jennifer is young, so editors do not know it out of the box.
This talk goes through every editor and tool we ship a definition for, shows
how to install it and how to tell that it works. Pick the slides for your
editor; you can skip the rest.
-->

---

## What we ship

| File in `editors/` | For |
| --- | --- |
| `vim/` | Vim and Neovim |
| `vscode/` | VS Code (a small extension) |
| `textmate/jennifer.tmLanguage.json` | editors that read TextMate™ grammars |
| `sublime/jennifer.sublime-syntax` | Sublime Text and `bat` |
| `highlightjs/jennifer.js` | web pages with highlight.js |
| `chroma/jennifer.xml` | Forgejo™, Gitea™, Hugo™ (a draft) |

<!-- notes:
All definitions live in the editors folder of the Jennifer repository. They
describe the same language, so they colour the same things: dollar variables,
upper case constants, type names, namespaced calls like strings.split,
comments, docblocks and strings with interpolation slots. Each was checked
against the interpreter's own lexer over every Jennifer file in the project.
-->

---

## Getting the files

The packages install two of them for you:

| Package | Installs |
| --- | --- |
| Arch™, Debian™ | Vim and Neovim syntax, `jennifer.sublime-syntax` |
| any | nothing for VS Code or the others |

Everything else comes from the repository:

```sh
git clone https://github.com/jennifer-language/jennifer.git
cd jennifer/editors
```

<!-- notes:
If you installed Jennifer from the Arch or Debian package, Vim and Neovim
already highlight Jennifer, and the Sublime syntax sits in
/usr/share/jennifer/syntaxes. For every other editor, clone the repository
once and copy from its editors folder. Pull again from time to time: Jennifer
is not 1.0 yet, and the grammars follow the language.
-->

---

## Vim and Neovim

From a package: nothing to do. By hand:

```sh
# Vim
mkdir -p ~/.vim/syntax ~/.vim/ftdetect
cp vim/syntax/jennifer.vim   ~/.vim/syntax/
cp vim/ftdetect/jennifer.vim ~/.vim/ftdetect/

# Neovim: the same two files under ~/.config/nvim/
mkdir -p ~/.config/nvim/syntax ~/.config/nvim/ftdetect
cp vim/syntax/jennifer.vim   ~/.config/nvim/syntax/
cp vim/ftdetect/jennifer.vim ~/.config/nvim/ftdetect/
```

<!-- notes:
Vim needs two files. The ftdetect file tells it that a file ending in .j is
Jennifer; the syntax file says how to colour it. Vim and Neovim look in
different folders, so copy them to the one your editor uses, or to both. With a
plugin manager, you can point it at the vim folder of the repository instead.
-->

---

## Vim: does it work?

```text
:set filetype?
  filetype=jennifer
```

- A `.j` file is Jennifer
- So is a script without an extension whose first line is
  `#!/usr/bin/env -S jennifer run`
- Nothing coloured? Check `:syntax on` in your vimrc

<!-- notes:
Open a Jennifer file and type colon set filetype question mark. It should say
jennifer. The detection also looks at the first line, so an executable script
without the .j ending is found by its shebang line. If the file type is right
but nothing is coloured, syntax highlighting is switched off in your vimrc;
syntax on switches it on.
-->

---

## VS Code on Linux and macOS

Copy the extension folder into VS Code's extensions:

```sh
cp -r vscode ~/.vscode/extensions/jennifer-0.2.0
```

Or link it, so `git pull` updates it:

```sh
ln -s "$(pwd)/vscode" ~/.vscode/extensions/jennifer-0.2.0
```

Then: Command Palette, **Developer: Reload Window**.

<!-- notes:
The VS Code extension is just a folder: a manifest, the grammar and the
settings for comments and brackets. There is no code in it that runs. Copy it,
or link it so that pulling the repository updates it. The folder name carries
the extension's version. After a reload, VS Code knows Jennifer.
-->

---

## VS Code on Windows

PowerShell™:

```powershell
Copy-Item -Recurse vscode `
  "$env:USERPROFILE\.vscode\extensions\jennifer-0.2.0"
```

`cmd.exe`:

```bat
xcopy /E /I vscode "%USERPROFILE%\.vscode\extensions\jennifer-0.2.0"
```

<!-- notes:
On Windows™ the extensions folder is in your user profile. Use whichever shell
you have; both commands copy the whole folder. A symbolic link works too but
needs an administrator shell or developer mode, so a copy is simpler. If you
use VS Code inside WSL™, follow the Linux™ slide for the Linux side.
-->

---

## VS Code: a package, and the check

As a single file, for any machine:

```sh
cd vscode
npx @vscode/vsce package          # gives jennifer-0.2.0.vsix
code --install-extension jennifer-0.2.0.vsix
```

Check: open a `.j` file; the status bar shows **Jennifer** as its language.

<!-- notes:
If you want to install the extension on several machines, package it once as a
vsix file and install that. It needs Node™ for the packaging step only. To check
that it works, open any Jennifer file and look at the language name in the
bottom right corner. It should say Jennifer, not Plain Text.
-->

---

## Sublime Text

Copy the syntax into your `User` package
(Preferences, Browse Packages):

| System | Folder |
| --- | --- |
| Linux | `~/.config/sublime-text/Packages/User/` |
| macOS™ | `~/Library/Application Support/Sublime Text/Packages/User/` |
| Windows | `%APPDATA%\Sublime Text\Packages\User\` |

```sh
cp sublime/jennifer.sublime-syntax ~/.config/sublime-text/Packages/User/
```

<!-- notes:
Sublime Text has its own syntax format, and we ship a native file for it.
Browse Packages in the Preferences menu opens the right folder on any system;
put the file into User there. Sublime picks it up at once, no restart needed.
The bottom right corner shows Jennifer for a .j file.
-->

---

## bat in the terminal

```sh
mkdir -p "$(bat --config-dir)/syntaxes"
cp sublime/jennifer.sublime-syntax "$(bat --config-dir)/syntaxes/"
bat cache --build
bat --list-languages | grep Jennifer
```

From a package, copy `/usr/share/jennifer/syntaxes/jennifer.sublime-syntax`.

<!-- notes:
bat is cat with colours, and it reads Sublime syntax files. It builds them into
a cache once, so after copying the file, rebuild the cache. The last command
shows that bat knows Jennifer now; then bat file.j prints it in colour. If you
installed a package, the syntax file is already on disk and you copy it from
there.
-->

---

## JetBrains IDEs and other TextMate editors

`textmate/jennifer.tmLanguage.json` is a TextMate grammar, scope
`source.jennifer`.

- **IntelliJ™, PyCharm™, GoLand™, ...**: Settings, Editor, TextMate Bundles,
  add the `editors/vscode` folder
- **Any editor with TextMate grammars**: point it at the `textmate/` file

<!-- notes:
Many editors understand TextMate grammars, the format VS Code uses too. The
JetBrains IDEs have a TextMate Bundles page in their settings that accepts a VS
Code extension folder, so the vscode folder works there as it is. For any
other editor that reads TextMate grammars, use the file in the textmate folder;
it is the original that the VS Code copy is made from.
-->

---

## Web pages: highlight.js

```html
<script src="highlight.min.js"></script>
<script src="jennifer.js"></script>
<script>hljs.highlightAll();</script>
```

Then mark code blocks as `jennifer`. In a build step:

```js
hljs.registerLanguage("jennifer", require("./jennifer.js"));
```

<!-- notes:
For a blog, a documentation site or any page that already uses highlight.js,
load jennifer.js after highlight.js and it registers itself. Code blocks marked
as jennifer are coloured from then on. In a build pipeline, require it and
register it by hand. It works with highlight.js versions 10 and 11, so older
tools like mdBook™ can use it too.
-->

---

## Forgejo, Gitea and Hugo

- They highlight with Chroma™, which compiles its lexers in
- `chroma/jennifer.xml` is a draft for Chroma itself: no server shows
  Jennifer until a release carries it
- Until then, a rough stand-in in Forgejo's or Gitea's `app.ini`:

```ini
[highlight.mapping]
.j = php
```

<!-- notes:
Self-hosted forges and Hugo use the Chroma highlighter, and Chroma cannot load
a lexer from a file at run time; it has to be built in. Our lexer is ready as a
contribution to Chroma, but your server only benefits once a Chroma release
includes it and your forge updates. Mapping .j to PHP until then gets dollar
variables and strings roughly right.
-->

---

## GitHub

- GitHub™'s language detection assigns `.j` to Objective-J
- So `.j` files on github.com are not coloured as Jennifer
- Nothing to do on our side: it works everywhere else

<!-- notes:
On github.com, Jennifer files are coloured as Objective-J or not at all,
because GitHub's detection maps the .j ending to that older language. That is
GitHub's decision, and we cannot change it from here. Your local editors, our
website and self-hosted tools are not affected. Do not be surprised by odd
colours when you browse code on GitHub.
-->

---

## Already built in

No setup needed in Jennifer's own tools:

- **Cantrip** colours Jennifer on slides, like these
- **Grimoire** colours it in documentation sites and PDFs
- The website and docs at [jennifer-lang.dev](https://jennifer-lang.dev/)

<!-- notes:
The project's own tools have their own highlighter, written in Jennifer, so
they need none of the files from this talk. The slides you are reading come
from Cantrip; every deck's documentation book comes from Grimoire; both colour
Jennifer code blocks by themselves. Only your own editor and your own website
need the setup shown here.
-->

---

## Your editor is missing?

Welcome as contributions: Emacs™ (`jennifer-mode.el`), nano (`.nanorc`), a
tree-sitter grammar (for Zed™, Helix™, Neovim).

- `editors/README.md` lists the token classes to cover
- Check your definition against `jennifer tokens file.j`

<!-- notes:
If your editor is not on the list, you can help. The editors README lists
every kind of token a definition has to colour, and jennifer tokens shows how
the interpreter itself splits a file, so you can compare. A tree-sitter grammar
would bring Jennifer to Zed and Helix and give Neovim better highlighting.
-->

---

## Where to go next

- The files: [github.com/jennifer-language/jennifer](https://github.com/jennifer-language/jennifer), folder `editors/`
- *Vibecoding with Jennifer*, in the [Jennifer Academy](https://academy.jennifer-lang.dev/):
  set up an AI assistant next to your editor
- The language: [docs.jennifer-lang.dev](https://docs.jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
Everything in this talk comes from the editors folder of the Jennifer
repository, with a README that has the same steps in more detail. If you want
an assistant to write Jennifer in the editor you just set up, the vibecoding
talk shows how. And the documentation explains the language whose colours you
now see.
-->

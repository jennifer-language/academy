---
theme: grimoire
ratio: 16:9
transition: fade
---

# Writing plugins for Grimoire and Cantrip

![Jennifer](jennifer-logo.png)

One JSON request in, one JSON reply out: how a diagram or a formula gets into a
book and a slide deck, with grimoire-mermaid and grimoire-katex as the worked
examples.

Based on **Jennifer 0.27.0**, Grimoire 0.6.1 and Cantrip 0.7.3, November 2026,
by [@mplx](https://github.com/mplx).

<!-- notes:
Grimoire builds books, Cantrip builds slide decks, and neither draws diagrams or
typesets maths itself. Both hand that job to plugins: separate programs that
speak one small JSON contract. This talk reads that contract from the source of
both tools, then walks through the two plugins that use it today, the Mermaid
diagram plugin and the KaTeX maths plugin, and a skeleton you can
start your own from. Every output shown is from a real run.
-->

---

## The plan

| Part | What |
| --- | --- |
| The contract | request, reply, versions, features |
| Finding and trusting | names, `PATH`, `grimoire plugins` |
| A skeleton | `grimoire-shout`, in this talk's code folder |
| grimoire-mermaid | fences, generated files, names |
| grimoire-katex | MathML, display and inline, safety |
| Limits | caps, timeouts, errors |
| Shipping | tests, layout, `jvc app install` |

<!-- notes:
Three parts. First the contract as the hosts implement it, which is the same in
Grimoire and Cantrip. Then the skeleton, small enough to read whole, which shows
every step without any library help. Then the two real plugins, which add what
production needs: generated pictures, MathML, concurrency, strict settings and a
test suite that runs against a fake renderer.
-->

---

## Why a program, not a module

- `import` is resolved when Jennifer **parses**: an installed Grimoire cannot
  load code it was not built with
- So the extension point is a **process**: one per plugin per build
- Any language works; the contract is JSON on stdin and stdout
- Cantrip speaks **the same contract**, api 1, unchanged

| | Plugins since | Kinds |
| --- | --- | --- |
| Grimoire | 0.4.0 (`files`, `mathml`: 0.5.0) | preprocessor, renderer |
| Cantrip | 0.6.0 | preprocessor only |

<!-- notes:
A Jennifer module is linked in at parse time, so there is no way to drop a new
.j file next to an installed Grimoire and have it loaded. A program is the
extension point that remains, and it costs one process start and one JSON round
trip per plugin per build. Cantrip adopted Grimoire's contract in 0.6.0, so one
preprocessor serves both. Cantrip refuses a renderer table, because a sitemap or
an EPUB is about books, not decks.
-->

---

## Naming one

```toml
# grimoire.toml                    # cantrip.toml, beside talk.md
[preprocessor.mermaid]             [preprocessor.mermaid]

[preprocessor.katex]               [preprocessor.katex]
program = "/opt/katex/bin/katex"   inline = false
```

| Host | Tries, in order |
| --- | --- |
| Grimoire | its own `plugins/` dir, then `PATH`: `grimoire-NAME`, then `cantrip-NAME` |
| Cantrip | `PATH`: `cantrip-NAME`, then `grimoire-NAME` |
| either | `command = "tools/x"`: a path, used as written |

<!-- notes:
An empty table is enough. The table name picks the program, so publish a plugin
as grimoire-NAME or cantrip-NAME and both tools find it. Every other key in the
table is the plugin's own and arrives in the request as plugin.settings; the
host reads only command and args. That is why the real plugins call their
renderer's path program and not command. A command with a slash is a path:
relative to the working directory in Grimoire, to the deck's directory in
Cantrip.
-->

---

## The request, as Cantrip sent it

```json
{"api": 1, "kind": "preprocessor",
 "features": ["files", "mathml"],
 "book": {"title": "Plugin deck", "authors": [], "language": "",
   "src": "/home/me/deck", "out": "/home/me/deck",
   "generated": "/tmp/cantrip-plugins-29/_generated"},
 "plugin": {"name": "dump", "settings": {"style": "dark"},
   "files": "/tmp/cantrip-plugins-29/_generated/dump"},
 "entries": [{"kind": "page", "title": "A diagram",
   "src": "talk.md", "out": "talk.md", "level": 0, "number": "1"}],
 "chapters": [{"src": "talk.md", "content": "---\ntheme: ..."}]}
```

<!-- notes:
This was captured with a three-line shell plugin that saved its stdin, then
shortened. A deck is a book of one chapter per input file, front matter
included. entries is the outline, chapters the text. plugin.files is an empty
directory made for this run; anything written there is published under
_generated slash the table name. features lists what this host offers beyond
api 1: here generated files and MathML.
-->

---

## The reply, and the rules

```json
{"api": 1, "chapters": [{"src": "talk.md", "content": "..."}]}
```

| Rule | |
| --- | --- |
| `api` | must be `1`; refuse a request with another number |
| sparse | only the chapters you changed; a chapter the book lacks is an error |
| no new chapters | the outline decides what a book holds |
| exit status | not `0` stops the build; your stderr is the message |
| stdout | the reply and nothing else; diagnostics go to stderr |
| deterministic | same request, same reply, same file names |

<!-- notes:
The hosts check the reply strictly: Grimoire's merge in src/plugin.j and
Cantrip's in src/plugin.j both refuse a reply without api 1, and both refuse a
chapter the book does not have. Determinism is the one rule nobody can check
for you. Grimoire promises byte-identical output at any number of jobs, and a
plugin that writes a timestamp or a random file name breaks that promise for
the whole book.
-->

---

## One run, step by step

![grimoire-mermaid in one build](plugin-run.png)

1. The host writes the request to the plugin's stdin and waits
2. The plugin hands each diagram to its renderer
3. The renderer writes an SVG and a PNG into `plugin.files`
4. The reply links them as `_generated/mermaid/<hash>.svg`

<!-- notes:
The picture was drawn by merman-cli, the renderer grimoire-mermaid runs, with
the same arguments the plugin uses. The host never sees the picture's bytes in
the reply: it gets Markdown with an image link, and finds the file in the
directory it handed out. Grimoire copies it into the site and the EPUB. The PDF
draws the PNG beside the SVG. Cantrip embeds the SVG in the slideshow as a data
URL.
-->

---

## Who runs what

```text
$ cantrip plugins talk.md
preprocessor  mermaid  ->  /usr/bin/grimoire-mermaid  (found on PATH)
preprocessor  katex    ->  /usr/bin/grimoire-katex  (found on PATH)

$ cantrip build talk.md
cantrip: warning: preprocessor mermaid: runs /usr/bin/grimoire-mermaid,
         found on PATH rather than in this deck
```

- Nothing is discovered: a program runs only when the file names it
- It runs **with your permissions**; read a stranger's `cantrip.toml` first
- From `PATH` or outside the tree: a warning on every build
- `jennifer-tiny` cannot start a process, so it refuses such a build

<!-- notes:
The security model is honesty, not a sandbox. The table in the configuration
is the gate, and both tools say out loud which program answers to each name and
where it came from. A plugin shipped with Grimoire, or kept inside the book's
own tree, passes quietly because reading the repository shows it. Grimoire
itself fetches nothing while it builds; a plugin that needs the network or a
binary says so in its README and a NEEDS file.
-->

---

## A skeleton: grimoire-shout

```text
code/bin/grimoire-shout     the launcher: stdin in, exit status out
code/src/shout.j            the module: every step of the contract
code/src/shout_test.j       ten tests, spliced in by jennifer test
```

```jennifer excerpt
export func run(text as string) {
    try {
        io.printf("%s", replyFor(request($text)));
        return 0;
    } catch (e) {
        io.eprintf("%s: %s\n", NAME, $e.message);
        return 1;
    }
}
```

<!-- notes:
The skeleton rewrites every shout fence by handing its text to awk, which
upper-cases it, and puts the output back as a text fence. That is useless on
purpose: what matters is the frame around it. The launcher only reads stdin and
exits with run's status. The module never calls exit, because jennifer test
loads it, and an exit inside a module would end the test runner too.
-->

---

## Check the request, then the settings

```jennifer excerpt
if (json.typeOf($req, "/api") != "int" or
    json.asInt($req, "/api") != API) {
    fail("this plugin speaks api 1 only");
}
if (json.asString($req, "/kind") != "preprocessor") {
    fail("this is a preprocessor");
}
for (def key in json.keys($req, "/plugin/settings")) {
    if (not (inList(SETTINGS, $key) or inList(HOST_KEYS, $key))) {
        fail("unknown setting `{$key}`");
    }
}
```

<!-- notes:
Refuse what you do not understand. Another api number means the request may
have another shape, so guessing is worse than stopping. An unknown setting is a
typo or a key meant for another plugin, and building without it would quietly
draw something nobody asked for. Allow the host's own command and args keys:
Grimoire and Cantrip pass the whole table through, those two included.
-->

---

## Fences, the CommonMark way

`````markdown
```shout
plugins are programs
```

````markdown
```shout
this one is an example, inside a longer fence
```
````
`````

- Three or more backticks or tildes, up to three spaces in
- Closed by at least as many of the same character
- An unclosed fence of yours is an error naming `chapter:line`

<!-- notes:
The first fence is rewritten, the second is not: it sits inside a four-backtick
fence, so it is the text of an example. Both real plugins rely on Grimoire's
plugin kit for this, which also handles indentation inside list items; the
skeleton does the same with two regular expressions. An unclosed fence would
otherwise swallow the rest of the chapter, so it stops the build at the line
where it opened.
-->

---

## Caps and a timeout

```jennifer excerpt
def started as time.Time init time.now();
while (not os.poll($p)) {
    if (time.milliseconds(time.sub(time.now(), $started)) >= $ms) {
        os.kill($p);
        os.wait($p);
        os.release($p);
        throw Error{kind: "timeout", message: "over {$ms} ms"};
    }
    time.sleep(time.fromMilliseconds(10));
}
```

The hosts wait for a plugin **without a timeout**, and so does `os.run`: bound
your own child processes, and cap input and output sizes.

<!-- notes:
Neither Grimoire nor Cantrip puts a clock on a plugin: both call os.run and wait.
A plugin that starts a renderer has to bound it itself. In Jennifer 0.27.0
that is os.spawn with a poll loop and os.kill, as here; os.spawn takes no stdin,
so the input goes in a temporary file. Caps throw the generic kind limit, the
timeout the generic kind timeout, so a caller can tell them from a plain refusal.
-->

---

## grimoire-mermaid: a fence becomes a picture

````markdown
```mermaid
flowchart LR
  accTitle: From Markdown to a book
  A[Markdown] --> B[Site]
```
````

```markdown
![From Markdown to a book](_generated/mermaid/6b79d22118f154bc.svg)
```

| Setting | Default | |
| --- | --- | --- |
| `renderer` | `"merman"` | or `"mmdr"` |
| `theme`, `font`, `png`, `scale`, `jobs` | | picture and speed |

<!-- notes:
The fence is replaced by a paragraph holding only the picture, with a blank line
on either side so it neither joins the paragraph above nor swallows the one
below. The alt text is the diagram's accTitle, which is also what the printable
book prints when it cannot draw the picture. A fence inside a list item keeps
its indentation, so the picture stays in the item. It needs the files feature,
and refuses a host that lacks it.
-->

---

## grimoire-mermaid: names and determinism

```jennifer excerpt
return kit.contentName(
    [
        "grimoire-mermaid 1",
        $r.settings.renderer,
        $r.version,
        $r.settings.theme,
        $r.fontDigest,
        $png,
        scaleText($r.settings.scale),
        $source
    ],
    NAME_DIGITS);
```

<!-- notes:
The file name is a hash of everything that changes the picture and nothing
else: the renderer and its version, the theme, the font by content rather than
path, whether a PNG is written, the scale, and the source. The same diagram
twice is drawn once, a rebuild writes the same names, and a new renderer release
redraws the book instead of mixing old pictures with new. Diagrams render in
parallel; the reply does not depend on which finishes first.
-->

---

## grimoire-katex: TeX in, MathML out

````markdown
Inline maths sits in the line: $`a^2 + b^2 = c^2`$.

```math
\sum_{i=1}^{n} i = \frac{n(n+1)}{2}
```
````

- Display: the `<math>` element as an HTML block, **opening tag alone** on its
  line, a blank line on either side
- Inline: in the line, with `` * _ ` [ ] `` and friends as numeric entities
- Needs the `mathml` feature; the PDF prints the TeX source in monospace

<!-- notes:
The syntax is GitHub™'s: a math fence for display maths, a dollar-backtick code
span for inline maths. Plain dollars are not maths, because a technical book is
full of dollar HOME. KaTeX wraps its output in a span for its own CSS; the
plugin keeps only the math element, which the browser draws without any
stylesheet or font download. Markdown still reads the text between inline tags,
so characters it would treat as emphasis or links become entities.
-->

---

## grimoire-katex: safe by construction

```jennifer excerpt
def out as list of string init [
    "-F", "mathml",
    "-e", MAX_EXPAND,     # at most 1000 macro expansions
    "-s", MAX_SIZE,       # no size above 100 em
    "-c", ERROR_COLOUR    # spot what KaTeX drew instead of failing
];
```

- `--trust` is never passed: `\href` and `\url` are refused
- `--no-throw-on-error` is never passed: bad TeX stops the build
- Caps: 64 KiB of TeX per formula, 1 MiB of MathML

<!-- notes:
The macro expansion limit is what keeps a runaway macro from hanging the build,
since the plugin itself puts no clock on katex. KaTeX draws a command it may not
run, such as a link without trust, in its error colour rather than failing. The
plugin passes an unlikely colour, looks for it in the output, and turns a hit
into an error. Each distinct formula is typeset once.
-->

---

## What a reader sees when it fails

```text
$ cantrip build talk.md
cantrip: preprocessor katex: exited 1: grimoire-katex: talk.md:16:
  KaTeX parse error: Unexpected end of input in a macro argument,
  expected '}' at end of input: ...2\,dx = \frac{1

cantrip: preprocessor mermaid: exited 1: grimoire-mermaid: talk.md:8:
  merman-cli: Diagram parse error (flowchart-v2): unexpected end
  of input

cantrip: preprocessor mermaid: exited 1: grimoire-mermaid:
  unknown setting `bogus`; the settings are renderer, program, ...
```

<!-- notes:
These are real runs, wrapped to fit. The host prefixes its own words, the
plugin names itself, then the chapter and the line of the fence, then the
renderer's first message line. KaTeX prints a Node™ stack trace; the plugin
keeps only the ParseError line. That chain is the whole user interface of a
plugin, so make every refusal name the place in the book and what to change.
-->

---

## Testing a plugin

| Test | How |
| --- | --- |
| fences, settings, rewrite | pure functions, white-box overlay `NAME_test.j` |
| refusals | `testing.assertThrows("unclosed", "plugin")` |
| the renderer's side | `tests/fake-renderer`, a shell stand-in set as `program` |
| real output | same bytes twice, when the real tool is installed |
| end to end | `scripts/check-example.sh`: build `examples/book` |

```sh
jennifer test src/shout_test.j        # from code/: 10 passed
```

<!-- notes:
The fake renderer is a small shell script that reads the diagram and writes a
file where the arguments say. Words in the diagram steer it: BROKEN fails like a
real renderer, SLOW finishes late, SILENT writes nothing. That covers error
paths and ordering without merman installed. The tests against the real tool
only check what matters: two builds give the same bytes, and bad input stops
the build with the tool's message.
-->

---

## Shipping one

```text
bin/grimoire-NAME     the launcher
src/NAME.j            the module
src/NAME_test.j       its tests
src/pluginkit.j       a copy of Grimoire's kit, if you use it
deck.toml             unscoped name, bin = "bin/grimoire-NAME"
NEEDS                 one required command per line
```

```sh
jvc app install https://github.com/mplx/grimoire-katex
```

<!-- notes:
That layout is a Jennifer app, which is how jvc installs a program onto PATH.
The package name becomes the command, and the command is what the host looks
for, so renaming the package breaks every book that uses it. The kit is copied,
not imported from the Grimoire deck, which would vendor all of Grimoire. Tag the
repository grimoire-plugin, and list in the README and NEEDS what a build now
needs that it did not before.
-->

---

## Read more

- The contract: [Grimoire's plugin chapter](https://grimoire.jennifer-lang.dev/plugins.html)
  and [Cantrip's](https://cantrip.jennifer-lang.dev/plugins.html)
- The plugins: [grimoire-mermaid](https://github.com/mplx/grimoire-mermaid),
  [grimoire-katex](https://github.com/mplx/grimoire-katex)
- Others: [topic grimoire-plugin](https://github.com/topics/grimoire-plugin)
- The skeleton: this talk's code folder

Based on Jennifer 0.27.0, Grimoire 0.6.1, Cantrip 0.7.3, November 2026.

<!-- notes:
Both manuals document the same contract; Grimoire's has the full field list,
the plugin kit's functions and the versioning rules, Cantrip's what a deck puts
in the request. The two plugin repositories are the best reading after this
talk: six to eight hundred lines of module each, plus their tests. The skeleton in the code
folder builds with Grimoire and Cantrip as they are released.
-->

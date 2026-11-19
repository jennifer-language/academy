---
theme: ivy
ratio: 16:9
transition: fade
---

# Introduction to Markdown

![Jennifer](jennifer-logo.png)

Plain text that reads well as it is and renders into books, slides and web
pages: the Markdown that Grimoire and Cantrip understand.

by [@mplx](https://github.com/mplx)

<!-- notes:
Markdown is how you write for the Jennifer project: the manual is Markdown
built by Grimoire, every talk in this academy is Markdown built by Cantrip, and
so are the README files of every repository. This talk covers exactly the
Markdown those two tools support, with the source on each slide and, where it
fits, the rendered result right below it. The slides themselves are an example.
-->

---

## Text that reads as it is

````markdown
# A heading

## A smaller heading

A paragraph is lines of text. A blank line
starts the next one.
````

- `#` to `######`: six levels of headings
- A blank line between blocks; a single line break joins lines

<!-- notes:
Markdown was designed so the source is as readable as the result. A hash and a
space start a heading, and more hashes make a smaller one, down to six. Text
on consecutive lines forms one paragraph, so you can wrap your lines wherever
you like; a blank line starts a new paragraph. Most formatting mistakes are a
missing blank line between two blocks.
-->

---

## Emphasis and inline code

````markdown
**bold**, *italic*, `code`, ~~struck~~, ==marked==, H~2~O, x^2^
````

**bold**, *italic*, `code`, ~~struck~~, ==marked==, H~2~O, x^2^

<!-- notes:
Two asterisks make text bold and one makes it italic. Backticks mark code,
which is shown in a fixed-width font and never formatted further. The last
four are extensions that Grimoire and Cantrip both support: two tildes strike
text through, two equals signs highlight it, and single tildes and carets make
a subscript and a superscript, as in water and squared.
-->

---

## Lists

````markdown
- milk
- bread
  - white
  - rye

1. preheat the oven
2. mix the dough
````

<!-- notes:
A dash and a space start a bullet list; an asterisk or a plus works too, but
stay with one style. Indent an item by two spaces to nest a list inside it.
A number with a full stop starts a numbered list. The numbers you write are
mostly decoration: the list counts on its own from the first one, so you can
insert a step without renumbering everything below it.
-->

---

## Task lists and definition lists

````markdown
- [x] written
- [ ] reviewed

deck
: a directory of Jennifer modules with a deck.toml
````

- [x] written
- [ ] reviewed

<!-- notes:
A task list is a bullet list whose items start with brackets: a space for open,
an x for done. Grimoire and Cantrip draw a checkbox the reader cannot tick,
because a page is not a form. A definition list is a term on one line and its
meaning on the next, after a colon. It is how a glossary or a list of options
is written, and both tools render it.
-->

---

## Links and images

````markdown
[the manual](https://docs.jennifer-lang.dev/)
<https://jennifer-lang.dev/>
![The Jennifer logo](jennifer-logo.png)
````

- The text in brackets is what the reader sees
- An image is a link with `!` in front; its text describes it
- A relative path points to a file next to the page

<!-- notes:
A link is the visible text in square brackets followed by the address in
parentheses. An address in angle brackets is shown and linked as it is. An
image adds an exclamation mark in front, and its bracket text is the
description a screen reader speaks, so write one. In this academy, links must
point into the Jennifer project and images must sit next to the talk.
-->

---

## Code blocks

````markdown
```jennifer
use io;

io.printf("Hello, world!\n");
```
````

- Three backticks open and close a block
- The word after them names the language for highlighting
- Grimoire: `title="hello.j"` after the language names the file

<!-- notes:
A fenced code block keeps every space and line exactly as written, which is
what code needs. The language after the opening fence selects the syntax
colours. Grimoire can also show a file name in the corner of the block. To
show a code block inside a code block, as this slide does, make the outer
fence longer: four backticks around three.
-->

---

## Tables

````markdown
| Tool     | Builds       | Output    |
| :------- | :----------: | --------: |
| Grimoire | books        | HTML, PDF |
| cantrip  | slide decks  | HTML, PDF |
````

| Tool     | Builds       | Output    |
| :------- | :----------: | --------: |
| Grimoire | books        | HTML, PDF |
| Cantrip  | slide decks  | HTML, PDF |

<!-- notes:
A table is rows of cells between pipes. The second row separates the header
from the body, and its colons set each column's alignment: a colon on the left
aligns left, on both sides centres, on the right aligns right. The columns do
not have to line up in the source, but lining them up keeps the table readable
for the next person who edits it.
-->

---

## Quotes and callouts

````markdown
> A quotation, marked like a reply in an email.

> [!TIP]
> Run `jennifer fmt -w` before you commit.
````

> [!TIP]
> Run `jennifer fmt -w` before you commit.

<!-- notes:
A greater-than sign starts a quotation, as in an email reply. A quotation that
opens with an exclamation mark in brackets becomes a callout: NOTE, TIP,
IMPORTANT, WARNING or CAUTION, each in its own colour. The syntax is the one
GitHub uses, so the same file reads correctly there, in Grimoire and in
Cantrip, and a tool that does not know it shows a plain quotation.
-->

---

## Anchors, classes and keys

````markdown
## Installing {#install}

[Download the PDF](book.pdf){.gr-button}

Press <kbd>Ctrl</kbd> + <kbd>C</kbd> to stop.
````

Press <kbd>Ctrl</kbd> + <kbd>C</kbd> to stop.

<!-- notes:
Curly braces after a heading give it a fixed anchor, so a link to it keeps
working when the heading text changes. On a link or an image, a dot and a name
add a CSS class; only the class is passed through, for safety. The kbd tag
draws a key cap in Cantrip, the one bit of HTML it accepts in a slide. In a
Grimoire book it is escaped like all inline HTML, whatever the settings.
-->

---

## What is not supported

- Footnotes: Grimoire shows `[^1]` as a bare number, no link
- Inline HTML is escaped (Cantrip: unless built with `--raw-html`)
- Cantrip: a bare `https://` address in text is not linked
- Cantrip: `---` separates slides, so it is not a rule or a heading underline

<!-- notes:
Knowing the limits saves time. Footnotes are the one common extension that is
missing in Grimoire. HTML in the text is shown as text, in Grimoire always
and in Cantrip unless a deck is built with raw-html, because a page should not
run code its author did not mean to. In Cantrip, wrap an address in angle brackets to
link it, and use three stars for a horizontal rule.
-->

---

## Grimoire: a book from a folder

````markdown
# Summary

[Introduction](index.md)

# Using Grimoire

- [Installation](installation.md)
- [Commands](commands.md)
````

<!-- notes:
A Grimoire book is a folder of Markdown files plus SUMMARY.md, which lists the
chapters in reading order. A heading in the summary starts a part, and a link
outside a list is a chapter without a number, such as an introduction. Grimoire
turns that into a website with search, a PDF and an EPUB. An HTML comment
saying pagebreak starts a new page in the printed book.
-->

---

## Cantrip: slides from one file

````markdown
---
theme: nordic
mode: dark
---

# The title slide

<!-- notes: what to say here -->

---

## The next slide
````

<!-- notes:
A Cantrip deck is one Markdown file. The front matter at the top picks the
theme and whether it opens light or dark. A line of three dashes starts the
next slide, and a comment that begins with notes holds what the speaker says,
which is hidden on the slide and shown in the notes panel. This talk is built
exactly that way.
-->

---

## Where to go next

- Grimoire's Markdown: [grimoire.jennifer-lang.dev](https://grimoire.jennifer-lang.dev/)
- Cantrip's slide format: [cantrip.jennifer-lang.dev](https://cantrip.jennifer-lang.dev/)
- Write a talk yourself: the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
Both tools render Markdown through the markdown module that ships with
Jennifer, so what works in one works in the other. The best practice is the
academy itself: its contributing guide explains how to add a talk, and a pull
request is checked automatically against the rules, including the ones about
notes and links you saw on these slides.
-->

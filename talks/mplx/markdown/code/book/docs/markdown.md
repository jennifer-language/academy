# Markdown

## Text that reads as it is

# A heading

## A smaller heading

A paragraph is lines of text. A blank line
starts the next one.

## Emphasis and inline code

**bold**, *italic*, `code`, ~~struck~~, ==marked==, H~2~O, x^2^

## Lists

- milk
- bread
  - white
  - rye

1. preheat the oven
2. mix the dough

## Task lists and definition lists

- [x] written
- [ ] reviewed

deck
: a directory of Jennifer modules with a deck.toml

## Links and images

[the manual](https://docs.jennifer-lang.dev/)
<https://jennifer-lang.dev/>
![The Jennifer logo](jennifer-logo.png)

## Code blocks

```jennifer title="hello.j"
use io;

io.printf("Hello, world!\n");
```

## Tables

| Tool     | Builds       | Output    |
| :------- | :----------: | --------: |
| Grimoire | books        | HTML, PDF |
| Cantrip  | slide decks  | HTML, PDF |

## Quotes and callouts

> A quotation, marked like a reply in an email.

> [!TIP]
> Run `jennifer fmt -w` before you commit.

## Anchors, classes and keys

### Installing {#install}

[Download the PDF](book.pdf){.gr-button}

Press <kbd>Ctrl</kbd> + <kbd>C</kbd> to stop.

## What is not supported

A footnote[^1] stays as written.

[^1]: like this one.

Inline HTML such as <b>bold</b> is shown as text.

A bare address https://jennifer-lang.dev/ in text.

---
title: The format on one deck
theme: ember
ratio: 16:9
transition: zoom
---

# The first slide

Some text.

---

## The second slide

- a point
- another point

***

A rule drawn with three stars.

---

---

## Code blocks

```jennifer
use io;

io.printf("{1 / 0}\n");
```

````markdown
```sh
cantrip build talk.md
```
````

<!-- notes:
A note may span
several lines.
-->

---

## Pictures

![The Jennifer logo](jennifer-logo.png)

![The first page of the report](report.png)

---

## More than bullet points

- [x] tables, task lists, footnotes[^1]
- [ ] bare URLs: https://jennifer-lang.dev/ stays text

term
: its definition

> [!WARNING]
> Not every viewer has a font for everything.

~~struck~~, ==marked==, H~2~O, x^2^, <kbd>Esc</kbd>, <b>escaped</b>

| Left | Centre | Right |
| :--- | :----: | ----: |
| a    | b      | c     |

[^1]: Cantrip 0.4.0 numbers and links them.

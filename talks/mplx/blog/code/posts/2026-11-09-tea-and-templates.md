+++
title = "Tea & templates"
date = 2026-11-09
summary = "How a layout and a page fit together, with <b> left as text."
+++

A template is HTML with *holes* in it. The program fills the holes
with the title, the date and the text of each post.

```text
{{ .post.title | html }}
```

The `html` pipe turns `&` into `&amp;`, so a title can never
break the page.

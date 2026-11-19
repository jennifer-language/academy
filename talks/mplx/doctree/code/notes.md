# Pipeline notes

## Readers

Three readers build **one** tree: `markdown`, `myst` and `rst`.
A transform sees no difference between them.

```{note}
A directive becomes an *admonition* node.
```

| Reader | Directives | Roles |
| --- | --- | --- |
| markdown | no | no |
| myst | yes | yes |
| rst | yes | yes |

## Writers

> Render once, print anywhere.

```jennifer
def out as bytes init doctree.renderPdf($doc, $opts);
```

Text outside WinAnsi, such as Gdańsk, is replaced.

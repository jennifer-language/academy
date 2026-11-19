# Code for "Your own small blog with Jennifer"

All programs run with a plain Jennifer 0.26.0 (`jennifer run`), from inside
this `code/` folder. No decks, servers or settings are needed.

| File | Slides | Run |
| --- | --- | --- |
| `build.j` | the whole talk: reads `site.toml`, `events.toml`, `posts/*.md` and `templates/*.tmpl`, writes the site to `public/` | `jennifer run build.j` |
| `serve.j` | "Previewing with a tiny web server": serves `public/` at http://127.0.0.1:8080/ until Ctrl-C | `jennifer run serve.j` (after `build.j`) |
| `markdown-demo.j` | "Markdown becomes HTML" | `jennifer run markdown-demo.j` |
| `escape-demo.j` | "Templates do not escape for you" | `jennifer run escape-demo.j` |

Data files:

- `site.toml`: the blog's title, address and author (placeholder values).
- `events.toml`: the events; only those still in the future are written to
  the home page and `public/events.ics`.
- `posts/`: one Markdown file per post, named `YYYY-MM-DD-slug.md`, with TOML
  front matter between two `+++` lines.
- `templates/`: `layout.tmpl` (with the style sheet), `index.tmpl` and
  `post.tmpl`, tengine templates.

`public/` is build output: delete it whenever you like, `build.j` writes it
again.

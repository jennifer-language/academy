# Docs that build themselves with Grimoire: the code

The sample books behind the slides, built and checked with Grimoire 0.5.0 on
Jennifer 0.26.0. Get Grimoire with
`jvc app install https://github.com/jennifer-language/grimoire`, from a
checkout (`git clone --branch 0.5.0
https://github.com/jennifer-language/grimoire`, then `grimoire/bin/grimoire`),
or use the container image `ghcr.io/jennifer-language/grimoire:0.5.0` with no
install. Build output (`site/`, the PDFs, the EPUB) is not kept here.

- `my-book/`: the book `grimoire init my-book` writes, with the
  configuration of the talk and a `reference/` folder added to the outline
  ("A book in a minute", "The outline: SUMMARY.md", "Tried on our book").
  Build, from `my-book/`: `grimoire build --pdf --verbose` (5 pages, the
  two reference chapters skipped in `site/my-book.pdf`)
- `my-book/grimoire.toml`: theme, edit link, highlighting and the printed
  book, with `exclude = ["reference/"]` ("grimoire.toml: what most books
  set", "The printed book"). `grimoire build --theme ivy` tries another
  theme without editing it.
- `my-book/grimoire-ref.toml`: the second book, only `docs/reference`
  ("Several books from one docs/ tree", "Tried on our book").
  Build, from `my-book/`: `grimoire pdf -c grimoire-ref.toml`
  (writes `site/my-book-reference.pdf`)
- `my-book/grimoire-epub.toml`: `grimoire.toml` plus the `epub` renderer
  ("The e-book: EPUB"). The optional `cover` and `stylesheet` keys are paths
  under `docs/`; they are left out here so the other builds copy no assets.
  Build, from `my-book/`: `grimoire build -c grimoire-epub.toml --pdf
  --verbose` (adds `site/my-book.epub`)
- `my-book/.github/workflows/docs.yml`: publishes the book to GitHub Pages
  from the highest release tag with Grimoire's reusable workflow; `prepare`
  renders the reference PDF into `docs/reference/` with the image, `check`
  fails the run when a PDF is missing ("CI: publish from the latest
  release", "Pages that write themselves"). Copy `my-book/` into a
  repository of its own; Pages must deploy from GitHub Actions and the
  `github-pages` environment must allow tags.
- `plugins-book/`: a one-page book that names the `include` preprocessor and
  the `sitemap` renderer; `docs/index.md` includes
  `docs/examples/hello.j` (include paths are relative to `docs/`) ("Plugins
  are programs", "Know what a book will run").
  Run, from `plugins-book/`: `grimoire plugins`, then `grimoire build`
  (writes `site/sitemap.xml` and `site/robots.txt`);
  `jennifer run docs/examples/hello.j` runs the included program.

The container commands of "Install it, or don't" and "The container image",
from `my-book/`:

```sh
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/work" \
    ghcr.io/jennifer-language/grimoire:0.5.0 build --pdf
docker run --rm --user "$(id -u):$(id -g)" -p 127.0.0.1:8080:8080 \
    -v "$PWD:/work" ghcr.io/jennifer-language/grimoire:0.5.0 \
    serve --watch --addr 0.0.0.0:8080
```

The image runs as its own user `jennifer`, so without `--user` it cannot
write `site/` into a directory you own. With Podman use `--userns=keep-id`
instead of `--user`.

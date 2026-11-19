# Jennifer resources: the commands

This talk is a collection of links, so there is no program behind it. These
are the commands its slides show, in the order they appear, for copying.
They were tried with Jennifer 0.26.0 and jvc 0.2.0 unless noted.

Installing the interpreter ("The interpreter"):

```sh
sudo apt install ./jennifer_0.26.0_amd64.deb   # AUR: jennifer-bin
docker run --rm -it ghcr.io/jennifer-language/jennifer repl
```

The `.deb` comes from the release page; installing it was not repeated here.
`docker pull ghcr.io/jennifer-language/jennifer` first if an older `latest`
is cached.

Decks and apps with jvc ("jvc: the package & app manager"), in a project
directory (`jvc init` writes its `deck.toml`):

```sh
jvc add "@deckyard/epub"          # require a deck
jvc install                       # vendor exactly what camcorder.lock pins
jvc app install https://github.com/jennifer-language/grimoire
jvc publish                       # tag, check, and announce your own deck
```

and in a program of that project:

```jennifer
import "@deckyard/epub/" as epub;
```

`jvc app install` puts a command on your PATH and `jvc publish` needs a
registry login and a tagged deck of your own; neither was run here.

Getting started ("Start here"):

```sh
jennifer repl                                  # try the language
jvc app install https://github.com/jennifer-language/grimoire
jvc add "@deckyard/geo" && jvc install         # your first deck
```

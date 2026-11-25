# Writing plugins for Grimoire and Cantrip: the code

`grimoire-shout`, the skeleton preprocessor from the slides, for Jennifer
0.27.0. It hands the text of every `shout` fence to `awk`, which upper-cases
it, and puts the output back as a `text` fence. It speaks the plugin contract
(api 1) without Grimoire's plugin kit, so every step is in one file. It needs
the default `jennifer` binary (it starts a process) and `awk`; nothing else, no
network.

The two real plugins the talk walks through are separate projects:
[grimoire-mermaid](https://github.com/mplx/grimoire-mermaid) and
[grimoire-katex](https://github.com/mplx/grimoire-katex).

Run everything from this folder.

- `bin/grimoire-shout`: the launcher. It reads the request on stdin and exits
  with the module's status ("A skeleton: grimoire-shout"). Try it on the
  sample request: `bin/grimoire-shout < request.json`
- `src/shout.j`: the module: request and settings checks ("Check the request,
  then the settings"), the fence scanner ("Fences, the CommonMark way"), the
  program run with caps and a timeout ("Caps and a timeout"), and the reply.
- `src/shout_test.j`: ten white-box tests, among them a refused api, unknown
  settings, an unclosed fence, the size cap and the timeout
  ("Testing a plugin"). Run: `jennifer test src/shout_test.j`
- `tests/slow.sh`: a program that takes too long, for the timeout test.
- `request.json`: a request as Grimoire or Cantrip sends it, shortened
  ("The request, as Cantrip sent it").
- `book/`: a Grimoire book that uses the plugin. Run:
  `cd book && PATH="$PWD/../bin:$PATH" grimoire build --pdf` (Grimoire 0.4.0
  or later; the build warns that the plugin was found on `PATH`, as it
  should).
- `deck/`: a Cantrip deck that uses it. Run:
  `cd deck && PATH="$PWD/../bin:$PATH" cantrip build talk.md` (Cantrip 0.6.0
  or later).

The `timeout` setting in `book/grimoire.toml` and `deck/cantrip.toml` is in
milliseconds (default 10000, at most 60000); `program` replaces `awk` with
another program that takes an awk script and a file.

# MCP servers in Jennifer: the code

The documentation server from the slides and its two test clients, for
Jennifer 0.26.0. The `mcp` and `web` modules ship with the interpreter, so no
`jvc install` is needed. Every program takes or serves a documentation
folder: use the `docs/` directory of a Jennifer source checkout (written
`DOCS_DIR` below). Run everything from this folder.

- `docs.inc.j`: the shared part, included by both servers: the page list
  below `DOCS_DIR`, the tools `search_docs` and `read_doc`, a resource per
  page and the prompt `explain_function` ("Start-up: the root and the page
  list", "`search_docs`: one tool handler", "`read_doc`: only pages from the
  list", "Register it, serve it", "Resources: every page", "A prompt:
  `explain_function`"). Not run on its own.
- `docs.j`: the server over stdio ("The sample: a documentation server").
  Run: `jennifer run docs.j DOCS_DIR` (it waits for JSON-RPC on stdin). For
  Claude Code or VS Code ("Claude Code: add the server", "VS Code") register
  it with absolute paths, for example
  `claude mcp add -s project jennifer-docs -- jennifer run /abs/path/docs.j /abs/path/docs`.
- `client.j`: calls every method once through the module's own stdio
  client, including both traversal attempts ("Testing with the module's own
  client"). It starts `docs.j` itself.
  Run: `timeout 30 jennifer run client.j DOCS_DIR`
- `wiretap.sh`: wraps `docs.j` with `tee` and writes the exchange to
  `wire.in` and `wire.out` next to the script ("What goes over the wire").
  Use it as the server command of a client, for example with the MCP
  Inspector ("Testing with the official Inspector"):
  `npx -y @modelcontextprotocol/inspector@2.14.0 --cli ./wiretap.sh DOCS_DIR --method tools/list`
  (needs Node.js; the Inspector is fetched by npx).
- `docshttp.j`: the same server over Streamable HTTP on
  `127.0.0.1:8931/mcp`, JSON replies only, with an Origin check and a bearer
  token ("Streamable HTTP, the stateless way", "Authentication, and why it
  matters"). The token comes from `DOCS_TOKEN` and must be at least 32
  characters.
  Run: `DOCS_TOKEN=example-token-0123456789abcdef0123456789 jennifer run docshttp.j DOCS_DIR`
- `httpclient.j`: calls `docshttp.j` with the module's HTTP client and the
  same token. Start `docshttp.j` first, then run:
  `DOCS_TOKEN=example-token-0123456789abcdef0123456789 jennifer run httpclient.j`
  A different token shows the `401` from the slide.

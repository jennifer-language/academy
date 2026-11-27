---
theme: carbon
ratio: 16:9
transition: slide
---

# Your own MCP server in Jennifer

![Jennifer](jennifer-logo.png)

A small server that serves the Jennifer documentation to an assistant:
two tools, every page as a resource and a prompt, tested with real
clients and connected to Claude™ Code and VS Code™.

November 2026, by [@mplx](https://github.com/mplx).\
Based on **Jennifer 0.27.0**

<!-- notes:
The companion talk, Talking to LLMs from Jennifer, is about the model side:
sending messages and running tools in your own program. This one is the other
direction: you write a server, and an assistant you already use calls it.
The example is practical: after this talk your assistant can look up a
Jennifer function in the real documentation instead of guessing. Everything
shown ran for real on Jennifer 0.27.0 with its bundled modules, against the
module's own client, the official MCP Inspector and Claude Code.
-->

---

## MCP in one slide

| Role | What it is | Example |
| --- | --- | --- |
| **Host** | the application the user talks to | Claude Code, VS Code |
| **Client** | one connection inside the host | one per server |
| **Server** | a program that offers context | `docs.j` |

- A server offers **tools** (the model calls them), **resources**
  (data the host reads) and **prompts** (templates the user picks)
- Underneath: JSON-RPC 2.0 messages, over **stdio** or **Streamable
  HTTP**, the two transports the specification defines

<!-- notes:
The Model Context Protocol is a contract between an assistant and the
programs that feed it. The model decides when to call a tool; the host
decides which resources go into the context; the user picks a prompt from a
menu. How the model itself is called is the topic of the LLM talk at
academy.jennifer-lang.dev/talks/mplx/llm-decks/, and not repeated here. The
transports matter later: stdio and Streamable HTTP are the only official
ones, and our server speaks both.
-->

---

## What goes over the wire

```text
-> {"method":"initialize","params":{"protocolVersion":"2025-11-25",...
<- {"result":{"protocolVersion":"2025-06-18","capabilities":
     {"tools":{},"resources":{},"prompts":{}},
     "serverInfo":{"name":"jennifer-docs","version":"0.1.0"}},"id":0}
-> {"method":"notifications/initialized"}
-> {"method":"tools/list","id":1}
<- {"result":{"tools":[{"name":"search_docs",...}]},"id":1}
-> {"method":"tools/call","params":{"name":"search_docs",
     "arguments":{"query":"path.clean"}},"id":2}
<- {"result":{"content":[{"type":"text","text":"docs://libraries/
     path.md (2x) ## Functions\n..."}],"isError":false},"id":2}
```

<!-- notes:
This is the real stdio exchange between the MCP Inspector CLI 2.14.0 and our
server, captured with tee, the jsonrpc fields shortened. The client asked for
protocol revision 2025-11-25; the server answered 2025-06-18, the revision
Jennifer's mcp module implements, and the client accepted it: that is version
negotiation. The notification has no id and gets no reply. Every later
request is one JSON line, every reply one line.
-->

---

## The `mcp` module in 0.26.0

- **Server:** `server`, `addTool` / `addResource` / `addPrompt`,
  `handle(server, body)` (one request in, one reply out),
  `serveStdio(server)`
- **Client:** `connect` / `connectWith` (HTTP), `connectStdio`, then
  `initialize`, `listTools`, `callTool`, `listResources`,
  `readResource`, `getPrompt`
- Protocol revision **2025-06-18**, stateless: no sessions, no
  server-sent events, no notifications from the server
- Dispatch is an **allow-list**: only registered items run

<!-- notes:
handle is the heart of it: it takes one JSON-RPC request as text and returns
the reply, or an empty string for a notification. serveStdio is a loop
around it, and for HTTP you wire it into the web module yourself, as we will.
Stateless means no Mcp-Session-Id, no progress or log notifications, no
sampling. Unlike jsonrpc.handle, which calls any top-level function by name,
mcp.handle only calls what you registered.
-->

---

## The sample: a documentation server

| Kind | Name | What it gives |
| --- | --- | --- |
| tool | `search_docs(query)` | pages that mention a phrase, a line each |
| tool | `read_doc(path)` | one page as Markdown |
| resource | `docs://libraries/json.md`, ... | every page, 168 of them |
| prompt | `explain_function(name)` | "explain json.decode from the docs" |

```sh
jennifer run docs.j ~/src/jennifer/docs     # read-only, stdio
```

<!-- notes:
The server takes one argument, the docs directory of a Jennifer checkout,
and only ever reads below it. There is no index and no database: 168
Markdown files, 2.6 MB, are searched on every call in well under a second.
docs.j is the stdio entry point in a few lines; the tools, resources and
prompt live in docs.inc.j, about 200 lines, which the HTTP variant later
includes too.
-->

---

## Start-up: the root and the page list

```jennifer excerpt
# os.ARGS[1]: exactly one argument, a directory, or exit 2
def root as string init fs.realpath(os.ARGS[1]);

func docPages() {
    def found as list of string init [];
    for (def st in fs.walk($root)) {
        if (not $st.isDir and strings.endsWith($st.path, ".md")) {
            $found[] = $st.path[len($root) + 1..];
        }
    }
    return lists.sort($found);
}
def pages as list of string init docPages();
```

<!-- notes:
fs.realpath makes the root absolute and resolves symlinks, so every path the
walk returns starts with it and can be cut to a relative name such as
libraries/json.md. fs.walk does not follow symlinks below the root, so a
link to /etc inside the docs cannot smuggle a file in. The page list is
built once, at start-up, and everything after this uses it: the search, the
read tool and the resources.
-->

---

## `search_docs`: one tool handler

```jennifer excerpt
func searchDocs(args as json.Value) {
    def q as string init strings.lower(
        requireString($args, "query", 100));
    def hits as list of Hit init [];
    for (def p in $pages) {
        def text as string init fs.readString($root + "/" + $p);
        def n as int init strings.count(strings.lower($text), $q);
        if ($n > 0) {
            $hits[] = firstHit($p, $text, $q, $n);
        }
    }
    # ... most hits first, the first 8 as lines of text ...
}
```

<!-- notes:
A tool handler is a top-level function taking the arguments as a json.Value.
Whatever it returns becomes the text content of the result. The module does
not check the arguments against the input schema, so requireString does: a
string, trimmed, 2 to 100 characters, otherwise it throws an Error of kind
value. firstHit finds the first matching line and the Markdown heading above
it, skipping comments inside code blocks, so the model sees where to look.
-->

---

## `read_doc`: only pages from the list

```jennifer excerpt
func readDoc(args as json.Value) {
    def p as string init strings.replace(
        requireString($args, "path", 200), "docs://", "");
    if (not lists.contains($pages, $p)) {
        return "No such page: " + $p + ". Use search_docs to find one.";
    }
    return fs.readString($root + "/" + $p);
}
```

```text
read_doc ../../../etc/passwd -> No such page: ../../../etc/passwd. ...
read_doc /etc/passwd         -> No such page: /etc/passwd. ...
```

<!-- notes:
The path comes from a model, so it is untrusted. Instead of cleaning it, the
handler accepts only an exact name from the page list: two dots, an absolute
path or a symlinked file are simply never in it, and no other file is ever
opened. That is stricter and simpler than a filter. The refusal is a normal
text result rather than a throw, because in 0.26.0 a throw reaches the model
only as "Tool execution failed", and this text tells it what to do instead.
-->

---

## Register it, serve it

```jennifer excerpt
def q as json.Value init mcp.property(mcp.schema(), "query",
    "string",
    "a word or phrase, 2 to 100 characters, such as json.decode",
    true);
def s as mcp.Server init mcp.server("jennifer-docs", "0.1.0");
$s = mcp.addTool($s, "search_docs",
    "Search the Jennifer language documentation. Use it before " +
    "answering a question about a Jennifer library, module or " +
    "function. Returns page paths with a matching line.",
    $q, searchDocs);
mcp.serveStdio($s);
```

- **stdout is the protocol.** Logs go to stderr, never `io.printf`

<!-- notes:
schema and property build a JSON Schema object; property's last argument
marks the field required. The builders return a new Server each time, so the
pattern is $s = mcp.addTool($s, ...), and the handler is passed by its bare
name. The description is written for the model: it says when to use the
tool, which decides whether the assistant ever calls it. read_doc is added
the same way. One stray io.printf would corrupt the protocol stream.
-->

---

## Resources: every page

```jennifer excerpt
func readResource(uri as json.Value) {
    def p as string init json.asString($uri, "")[7..];
    return fs.readString($root + "/" + $p);
}
# in docsServer():
for (def p in $pages) {
    $s = mcp.addResource($s, "docs://" + $p, $p,
        "Jennifer docs: " + $p, "text/markdown", readResource);
}
```

```text
resources/list                          -> 168, docs://SUMMARY.md first
resources/read docs://../../etc/passwd  -> -32602 "Resource not found"
```

<!-- notes:
Each page is registered under its own URI at start-up, all with the same
handler, which gets the URI it was asked for. Cutting the scheme off and
reading the file looks dangerous, but only registered URIs ever reach the
handler: the module answered the traversal URI with invalid params. Hosts
use resources differently: Claude Code lets you mention one with an at sign;
VS Code's Copilot™ sessions do not list them, which is why read_doc exists.
-->

---

## A prompt: `explain_function`

```jennifer excerpt
func explainFunction(args as json.Value) {
    def name as string init requireString($args, "name", 60);
    if (not regex.matches(
        "^[a-z][a-zA-Z0-9]*\\.[a-zA-Z][a-zA-Z0-9]*$", $name)) {
        throw Error{kind: "value", message: "name: lib.function"};
    }
    def text as string init "Explain the Jennifer function " +
        $name + ". Use the search_docs and read_doc tools; ...";
    def msg as json.Value init json.decode(
        '{"role":"user","content":{"type":"text","text":""}}');
    $msg = json.set($msg, "/content/text", $text);
    return json.append(json.list(), "", $msg);
}
```

<!-- notes:
A prompt handler returns the messages as a JSON list; each has a role and
one content block. The full text asks for the signature, the return value,
what it throws and an example, and the page used. The argument is checked
against a pattern before it goes into the text: a prompt is input to the
model too. A prompt handler that throws becomes error -32603, Internal error,
for the client. It is registered with addPrompt and one promptArg, name.
-->

---

## Testing with the module's own client

```jennifer excerpt
def c as mcp.Client init mcp.connectStdio(
    ["jennifer", "run", "docs.j", os.ARGS[1]]);
def a as json.Value init json.set(json.map(), "/query", "realpath");
def out as json.Value init mcp.callTool($c, "search_docs", $a);
io.printf("%s\n", json.asString($out, "/content/0/text"));
```

```text
docs://libraries/fs.md (4x) ## Metadata
    | `fs.realpath(path)` | `string`  | Absolute, symlink-resolved...
docs://libraries/cheatsheet.md (2x) ## Functions
    | [`fs`](fs.md)`.realpath(path)`                        | Absolu...
matching pages: 2; read one with read_doc.
```

<!-- notes:
client.j calls every method once: initialize, tools/list, both tools, the
traversal path, resources/list, resources/read with a good and a traversal
URI, and the prompt. connectStdio is one-shot: every call starts the server,
sends the handshake and one request, closes stdin and reads the replies, so
the whole test took under two seconds. The released client waits for the
child without a timeout, so run such tests under one.
-->

---

## Testing with the official Inspector

```sh
npx -y @modelcontextprotocol/inspector@2.14.0 --cli \
    jennifer run docs.j ~/src/jennifer/docs \
    --method tools/call --tool-name search_docs --tool-arg query=x
```

```text
{ "content": [ { "type": "text", "text": "Tool execution failed" } ],
  "isError": true }
```

- Also run: `tools/list`, `read_doc` with `../../../etc/passwd`,
  `resources/list`, `resources/read --uri ...`, `prompts/get`
- Without `--cli`: the same in a browser UI

<!-- notes:
The Inspector is the reference client of the MCP project and the second
opinion your own client cannot give. Every method of the docs server passed
through it, including both traversal attempts; paths are shortened. The call
shown is the
validation failure, a one-letter query: the thrown message stays on the
server, the model only learns that the call failed. A prompt argument such
as name=rm-rf got -32603. Pin the version, as with any tool fetched by npx.
-->

---

## Claude Code: add the server

```sh
claude mcp add -s project jennifer-docs -- \
    jennifer run /opt/jennifer-docs/docs.j /srv/jennifer/docs
```

```json
{ "mcpServers": { "jennifer-docs": {
    "type": "stdio", "command": "jennifer",
    "args": ["run", "/opt/jennifer-docs/docs.j", "/srv/jennifer/docs"],
    "env": {} } } }
```

`-s local` (default): you, this project; `project`: `.mcp.json`,
shared through git; `user`: you, every project.

<!-- notes:
Everything after the double dash is the command line Claude Code starts. With
project scope it writes the JSON shown into .mcp.json at the project root,
reformatted and with the paths shortened. Local and user scope keep the entry
in ~/.claude.json instead. The host starts the program with an unknown working
directory, so both paths are absolute. claude mcp remove jennifer-docs -s
project takes it out again.
-->

---

## Claude Code: approve, then ask

```text
$ claude mcp get jennifer-docs
  Scope: Project config (shared via .mcp.json)
  Status: Pending approval (run `claude` to approve)
$ claude -p "Which Jennifer function compares two byte strings in
    constant time, and what does it return? ..." \
    --mcp-config .mcp.json --allowedTools mcp__jennifer-docs__...
search_docs {"query":"constant time"}
search_docs {"query":"hash.equal"}
read_doc    {"path":"libraries/hash.md"}
The function is `hash.equal(a, b)` from the `hash` library ...
```

<!-- notes:
A server from .mcp.json is not trusted until you approve it in an interactive
claude session; the output is shortened, and the status line also carried a
pause icon. The headless run
loads the same file explicitly. Claude searched twice, read the page and
answered from it. /mcp__jennifer-docs__explain_function path.clean ran the
prompt the same way. Not tried here: the approval dialog itself and resource
mentions, which do not work in claude -p.
-->

---

## VS Code

```json
{
    "mcpServers": {
        "jennifer-docs": {
            "type": "stdio",
            "command": "jennifer",
            "args": ["run", "/opt/jennifer-docs/docs.j",
                     "/srv/jennifer/docs"],
            "tools": ["*"]
        }
    }
}
```

- `.mcp.json` at the workspace root or `~/.copilot/mcp-config.json`
- `.vscode/mcp.json` with a `servers` key: the deprecated Local harness

<!-- notes:
VS Code's MCP configuration reference, updated 18 November 2026, describes
this portable format for its Copilot harness: the same mcpServers shape and
the same .mcp.json Claude Code writes, plus tools to choose which tools are
offered. .vscode/mcp.json with a servers key belongs to the Local harness,
which the page calls deprecated and due for removal in February 2027. Its
prompt and resource menus are not in Copilot sessions. Not run in VS Code here.
-->

---

## Streamable HTTP, the stateless way

```jennifer excerpt
func postMcp(ctx as web.Context) {
    # ... Origin and bearer token checks, next slide ...
    def body as string init encoding.decode("utf-8",
        web.body($ctx));
    def reply as string init mcp.handle($srv, $body);
    if ($reply == "") {
        web.respond($ctx, 202, "");      # a notification
        return;
    }
    web.setHeader($ctx, "Content-Type", "application/json");
    web.respond($ctx, 200, $reply);
}
```

`POST /mcp` answers with JSON; `GET /mcp` with 405: no event stream.

<!-- notes:
docshttp.j includes the same docs.inc.j and serves it on one endpoint. The
client POSTs each message; the server may answer with plain JSON or open a
server-sent event stream. Answering JSON only and 405 on GET is allowed by
the specification, and it is all a stateless server needs. The real handler
catches a body that is not UTF-8 and answers 400. Streaming needs the
planned sse module, M30.9.
-->

---

## Authentication, and why it matters

```jennifer excerpt
def origin as string init web.header($ctx, "Origin");
if ($origin != "" and $origin != ORIGIN) {
    web.text($ctx, 403, "origin not allowed\n");
    return;
}
if (not hash.equal(utf8(web.bearerToken($ctx)), utf8($token))) {
    web.setHeader($ctx, "WWW-Authenticate", "Bearer");
    web.text($ctx, 401, "bearer token required\n");
    return;
}
```

```text
token: 2 matching pages | wrong token: RpcError, status 401
no token (Inspector): auth_required | other Origin: 403
```

<!-- notes:
Anyone who reaches the endpoint can call the tools. The server listens on
127.0.0.1 only, and the Origin check stops a web page that makes your browser
POST to localhost, which the specification asks servers to guard against.
The token comes from DOCS_TOKEN, at least 32 characters, compared with
hash.equal, which does not leak timing. Without it the Inspector got 401 and
started the OAuth discovery the specification describes.
-->

---

## Security: a tool runs with your rights

- **Least privilege:** this server only reads, and only below one
  directory; a separate server, user or container for anything else
- **Validate every argument**: the schema guides the model, the
  module does not check it
- **Allow-lists over filters**: exact page names, registered URIs
- **Never build a shell command** from tool input:
  `os.run(["sh", "-c", "grep -r " + $q])` runs whatever the model wrote
- **Cap the work**: query length, eight hits, a fixed page list

<!-- notes:
Tool arguments are written by a model, which may have read a web page with
instructions in it. That is prompt injection, and the defence is the server
refusing what it should not do. A grep subprocess would have been the quick
way to search; reading with fs and searching with strings.count keeps the
model's text out of any command line. If a tool needs a program, pass a list
to os.run and check each argument against an allow-list.
-->

---

## Read more

- [mcp](https://docs.jennifer-lang.dev/modules/mcp.html),
  [web](https://docs.jennifer-lang.dev/modules/web.html),
  [fs](https://docs.jennifer-lang.dev/libraries/fs.html) and
  [path](https://docs.jennifer-lang.dev/libraries/path.html)
- The model side: [Talking to LLMs from Jennifer](https://academy.jennifer-lang.dev/talks/mplx/llm-decks/)
- Not yet in 0.26.0: SSE, sessions, server notifications, resource
  templates, custom `isError` text
- The [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.27.0, November 2026.

<!-- notes:
The programs are small: docs.inc.j with the tools, resources and prompt,
docs.j for stdio in a few lines, docshttp.j for HTTP with a token, and
client.j as the test. The missing pieces listed are the edges of the
released module, not of MCP; streaming responses and the sse module are
planned for 0.28.0. Until then a stateless server over stdio or JSON-only
HTTP covers what most private servers need.
-->

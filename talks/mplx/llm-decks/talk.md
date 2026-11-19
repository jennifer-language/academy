---
theme: carbon
ratio: 16:9
transition: slide
---

# Talking to LLMs from Jennifer

![Jennifer](jennifer-logo.png)

Claude, GPT and Gemini side by side, with the `@deckyard/anthropic`,
`@deckyard/openai` and `@deckyard/gemini` decks: messages, tools, errors,
and tests that need no key.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
Three decks, one per vendor API, written in Jennifer over plain HTTPS. They
were aligned on purpose: the same builder names, the same tool loop, the same
usage fields, errors with the same core fields. This talk shows the shared
surface first and then where the three really differ. Every output on the
slides is from a real run of the decks against a fake server on a loopback
port; no request went to a vendor and no real key was used.
-->

---

## Three decks, one shape

| | `@deckyard/anthropic` | `@deckyard/openai` | `@deckyard/gemini` |
| --- | --- | --- | --- |
| API | Claude Messages | Chat Completions | Gemini generateContent |
| Key in the examples | `ANTHROPIC_API_KEY` | `OPENAI_API_KEY` | `GEMINI_API_KEY` |
| Model in the docs | `claude-opus-5-5` | `gpt-5.4-mini` | `gemini-3.8-flash` |
| Error struct | `AnthropicError` | `OpenaiError` | `GeminiError` |
| Also | batches, caching | Ollama, vLLM, Azure | files, caches |

Requests and replies are `json.Value` documents in each API's own shape.

<!-- notes:
Why three decks and not one? The wire formats differ in every part a client
touches: where the system prompt goes, how tool arguments arrive, the auth
header, the error shape. A common facade would hide what each API does well;
a provider-neutral llm deck over the three is planned separately. The
anthropic deck's DEFAULT_MODEL constant is claude-opus-5-5; the other two
decks name their model in the docs and examples only.
-->

---

## Setup: the key comes from the environment

```sh
jvc add "@deckyard/anthropic" "^0.1.0"   # likewise openai, gemini
jvc install                              # into vendor/deckyard/...
export ANTHROPIC_API_KEY=...             # from a secret store
```

- Every deck needs the `net` capability: the default `jennifer`
  binary, not `jennifer-tiny`
- The key is sent as a header, never in a URL, and replaced in every
  error message
- A `Client` holds the key: **never print one**

<!-- notes:
Read the key with os.getEnv at startup, fill the environment from a secret
store or a systemd credential, and keep it out of the repository. The decks
do their part: the key travels only as a header, x-api-key for Anthropic,
Authorization Bearer for OpenAI, x-goog-api-key for Gemini, and server text
that echoes it is cleaned before it reaches an error. What you print
yourself is your responsibility, so log errors, not clients.
-->

---

## A first message: Claude

```jennifer
use io; use json; use os;
import "@deckyard/anthropic/" as anthropic;

def key as string init os.getEnv("ANTHROPIC_API_KEY");
def c as anthropic.Client init anthropic.client($key);
def req as json.Value init anthropic.newRequest("claude-opus-5-5");
$req = anthropic.withSystem($req, "Answer in one sentence.");
$req = anthropic.addUserText($req, "Why is the sky blue?");
def reply as json.Value init anthropic.chat($c, $req);
io.printf("%s\n", anthropic.text($reply));
```

```text
Blue light is scattered most by the air (Rayleigh scattering).
```

<!-- notes:
The client is a plain value: key, base URL, deadline, retries. Builders such
as newRequest, withSystem and addUserText return a new request each time, so
the pattern is always $req = builder($req, ...). chat sends it and returns
the reply as JSON; text joins its text blocks. The answer shown came from
the fake server, which replays a reply in the shape of Anthropic's API
reference.
-->

---

## The same in GPT and Gemini

```jennifer excerpt
def c as openai.Client init openai.client($key);   # OPENAI_API_KEY
def req as json.Value init openai.newRequest("gpt-5.4-mini");
$req = openai.withSystem($req, "Answer in one sentence.");
$req = openai.addUserText($req, "Why is the sky blue?");
io.printf("%s\n", openai.text(openai.chat($c, $req)));
```

```jennifer excerpt
def c as gemini.Client init gemini.client($key);   # GEMINI_API_KEY
def req as json.Value init gemini.newRequest("gemini-3.8-flash");
$req = gemini.withSystem($req, "Answer in one sentence.");
$req = gemini.addUserText($req, "Why is the sky blue?");
io.printf("%s\n", gemini.text(gemini.chat($c, $req)));
```

<!-- notes:
Line for line the same program: client, newRequest, withSystem, addUserText,
chat, text. That is the aligned surface. Swapping vendors is a change of
namespace and model name, not a rewrite. Each deck also has extras under its
own names: withEffort and withThinking in anthropic, setSchema in openai,
withThinkingLevel and withJsonSchema in gemini. Those are where the APIs
really differ.
-->

---

## What actually goes on the wire

| | Anthropic | OpenAI | Gemini |
| --- | --- | --- | --- |
| Path | `/v1/messages` | `/v1/chat/completions` | `/v1beta/models/<id>:generateContent` |
| Model | in the body | in the body | in the path |
| System prompt | top-level `system` | a `system` message | `systemInstruction` |
| `max_tokens` | required, 16000 set | not set | not set |
| Key header | `x-api-key` | `Authorization: Bearer` | `x-goog-api-key` |

<!-- notes:
Print json.encode of a request to see it. Anthropic's has model, max_tokens
16000, messages and system. OpenAI's puts the instructions in a first
message with role system, which every compatible server understands. Gemini's
request carries contents with parts and a systemInstruction; chat moves the
model from the body into the URL. Anthropic requires max_tokens, so
newRequest sets one; withMaxTokens changes it.
-->

---

## Reading a reply

| | Anthropic | OpenAI | Gemini |
| --- | --- | --- | --- |
| Text | `text(reply)` | `text(reply)` | `text(reply)` |
| Why it stopped | `stopReason`: `end_turn` | `finishReason`: `stop` | `finishReason`: `STOP` |
| No answer | stop reason `refusal` | `refusal(reply)` | `blockReason(reply)` |

`usage(reply)` returns a `Usage` struct in all three: `inputTokens`
(cache included), `outputTokens`, `totalTokens`, `cachedTokens`,
`reasoningTokens`.

```text
[end_turn, 21 in, 17 out]    [stop, 24 in, 15 out]    [STOP, 9 in, 14 out]
```

<!-- notes:
The stop reasons keep each vendor's own spelling, so a program that checks
them is vendor-specific. A refusal is not an error in any of them: Claude
returns a reply with stop reason refusal, OpenAI a refusal text, Gemini a
block reason. Gemini is the one exception to "no throw": its text throws
kind gemini.blocked when there is no answer to return. Usage is normalised,
so token accounting code works unchanged across vendors.
-->

---

## A conversation: addReply

```jennifer excerpt
def reply as json.Value init gemini.chat($c, $req);
io.printf("%s\n\n", gemini.text($reply));
$req = gemini.addReply($req, $reply);
$req = gemini.addUserText($req, "Now explain it to a five-year-old.");
$reply = gemini.chat($c, $req);
```

- The APIs keep no state: each request carries the whole conversation
- `addReply` appends the reply **unchanged**: thinking blocks and their
  signatures must go back exactly as they came
- `addReply` exists in all three decks

<!-- notes:
This is from the gemini deck's chat example. The model's own turn goes back
into the request before the next user turn. Doing it by hand with a text
message is a trap: Claude's thinking blocks and Gemini's thought signatures
must be returned as they came, or the API may refuse the request. addReply keeps them; openai's version keeps reasoning_content too.
-->

---

## Streaming: not yet

- None of the three decks streams in 0.1.0: the bundled `http` cannot
  read a body incrementally yet
- Streaming arrives with a streaming `http` and server-sent events in
  core (planned, M30.9); openai refuses `stream: true` until then
- Meanwhile: a deadline long enough for the whole answer

| Deadline of one attempt | anthropic | openai | gemini |
| --- | --- | --- | --- |
| default | 10 min | 10 min | 5 min |
| change | `withTimeout(c, ms)` | `withTimeout(c, ms)` | `withTimeout(c, ms)` |

<!-- notes:
A long generation, or a model that thinks for minutes, sends no byte until
it is done, so the deadline is generous by default. Shorten it for quick
classification calls, for example withTimeout of 30000 milliseconds. For
large offline jobs Anthropic's Message Batches API is in the anthropic deck:
createBatch, waitBatch and batchResults, at half the price and with no
connection held open.
-->

---

## Tools: declare them

```jennifer excerpt
def schema as json.Value init json.decode(
    '{"type":"object","required":["item"],' +
    '"properties":{"item":{"type":"string"}},' +
    '"additionalProperties":false}');
def t as json.Value init anthropic.tool(
    "stock_level", "How many of an item are in stock.", $schema);
$req = anthropic.addTool($req, anthropic.withStrict($t));
```

- `tool(name, description, schema)`, `addTool`, `addTools`: all three
- `withStrict`: anthropic and openai; the input then matches the schema
- Gemini has no strict mode: check the arguments before acting

<!-- notes:
A tool is a name, a description the model reads to decide when to call it,
and a JSON Schema of its input. Strict mode makes the model's input always
match the schema, which requires additionalProperties false. Gemini's schemas
are an OpenAPI subset that steers the model; withToolMode with VALIDATED is
the closest it has. Whatever the vendor, tool input is model output: validate
it before it touches anything real.
-->

---

## Tools: the loop

```jennifer excerpt
func level(name as string, input as json.Value, stock as json.Value) {
    if ($name != "stock_level") {
        return anthropic.toolError("no tool " + $name);
    }
    def item as string init json.asString($input, "/item");
    if (json.typeOf($stock, "/" + $item) != "int") {
        return anthropic.toolError("unknown item " + $item);
    }
    def n as int init json.asInt($stock, "/" + $item);
    return json.decode('{"count":' + convert.toString($n) + '}');
}
```

`anthropic.runToolsWith($c, $req, level, $stock, 10)`, also in openai and gemini

<!-- notes:
runToolsWith sends the request, runs every tool call through the handler,
appends the results, and repeats until the model stops for something else or
the turn limit is reached. Jennifer has no closures, so the data the handler
needs, here a stock table, goes in as the context argument. toolError tells
the model a call failed so it can recover; a handler that throws ends the
loop with that error. The handler is the same in all three decks.
-->

---

## Tools: what happened

```text
fake: POST /v1/messages (x-api-key) -> 200, 381 bytes in
fake: POST /v1/messages (x-api-key) -> 200, 915 bytes in
Reorder nuts (80) and washers (0); bolts are fine (1200).
[3 tool calls in 2 requests, stopped ""]
```

| `ToolRun` field | Holds |
| --- | --- |
| `reply` / `request` | the last reply / the whole conversation |
| `turns` / `calls` | requests sent / tool calls run |
| `usage` | the `Usage` of every reply, summed |
| `stopped` | `""`: the model finished; `"maxTurns"`: the limit |

<!-- notes:
Two requests: the first reply asked for three stock_level calls at once, the
loop answered all three in one user turn, and the second reply was the
answer. The same run against the openai and gemini paths gave the same three
calls in two requests. After maxTurns nothing is lost: the request field
holds the conversation with the last results, ready for another runTools
call.
-->

---

## Errors: one struct per deck

| Field | `AnthropicError` | `OpenaiError` | `GeminiError` |
| --- | --- | --- | --- |
| `kind` | `"anthropic"` | `"openai"` | `"gemini"`, `"gemini.blocked"` |
| `status` | HTTP status, 0 if none | same | same |
| `retryAfterMs` | the wait asked for | same | same |
| `limits` | rate-limit headers | same | same |
| vendor's own | `type`, `requestId` | `type`, `code`, `param`, `requestId` | `googleStatus`, `reason`, `blockReason` |

<!-- notes:
Every failure of a deck's own kind is one struct, so once the kind matches,
every field is there to read. Status zero means no reply was read, or the
deck refused to send the request. retryAfterMs is the wait the server named
in retry-after-ms, retry-after or, for Gemini, RetryInfo. limits holds the
rate-limit headers with lower-case names. Messages never carry the key.
-->

---

## Errors: match the kind, then read fields

```jennifer excerpt
try {
    $reply = anthropic.chat($c, $req);
} catch (e) {
    if ($e.kind != "anthropic") {
        throw $e;
    }
    def err as anthropic.AnthropicError init $e;
    io.printf("HTTP %d %s, wait %d ms\n",
        $err.status, $err.type, $err.retryAfterMs);
}
```

```text
HTTP 429 rate_limit_error, wait 30000 ms
```

<!-- notes:
Check the kind first; anything else is passed on with throw, unchanged.
Declaring the caught value as anthropic.AnthropicError gives a typed variable
to hand to helpers: a parameter typed Error does not accept the struct. With
retries switched off, the fake's 429 with retry-after 30 arrived as shown;
openai reported code rate_limit_exceeded, gemini RESOURCE_EXHAUSTED, each
with the same 30000 ms. Never match the message text.
-->

---

## Generic kinds and built-in retries

- Passed on unchanged: `"net"` (a `net.NetError`), `"timeout"`,
  `"closed"`, `"limit"` (a reply over the cap), `"cancelled"`
- Retried: 408, 409, 429, 5xx, and a network failure **before** the
  request was sent; 2 times (gemini: 3), `withRetries(c, n)`
- Never resent once sent: a reset or a reply cut off mid-way could
  mean a second charge
- A server asking to wait over 60 s: thrown at once, the wait in
  `retryAfterMs`

<!-- notes:
These kinds are shared by every library in Jennifer, so a caller handles a
timeout the same way whatever deck threw it. The retry rule is the same in
all three decks. The wait is the server's own, else a backoff that doubles.
openai also skips a 429 whose type is insufficient_quota, since out of credit
is not cured by waiting.
-->

---

## OpenAI-compatible servers

```jennifer excerpt
def local as openai.Client init openai.withBaseUrl(
    openai.client(""), "http://127.0.0.1:11434/v1");
def az as openai.Client init openai.azure($endpoint, $azureKey);
```

- One client for OpenAI, Azure OpenAI, Ollama, vLLM, the llama.cpp
  server, LM Studio, OpenRouter, Groq, Mistral and more
- `client("")` sends no key; a local Ollama needs none
- Plain `http` goes only to loopback unless `withPlainHttp(c)`

<!-- notes:
The openai deck is the one that reaches local models. Its live test ran
against Ollama with a small Qwen model: chat, parallel tool calls through the
loop, a strict schema and embeddings. Error bodies of compatible servers
differ, a numeric code from llama.cpp for instance, and the deck reads those
variants into the same OpenaiError. Plain http to another machine would send
the key in clear, hence the opt-in.
-->

---

## Testing without a key

- Every client takes `withBaseUrl(c, url)`: point it at a fake
- The examples read `ANTHROPIC_BASE_URL`, `OPENAI_BASE_URL`,
  `GEMINI_BASE_URL`
- The decks' own suites start an `httpd` fake on `127.0.0.1:0` in a
  task and replay replies in the shapes of the API references

```jennifer excerpt
def c as anthropic.Client init anthropic.client($key);
if (os.hasEnv("ANTHROPIC_BASE_URL")) {
    $c = anthropic.withBaseUrl($c, os.getEnv("ANTHROPIC_BASE_URL"));
}
```

<!-- notes:
Tests that call a vendor cost money, need a key in CI and fail on a rate
limit, so none of the three suites does. The fakes record every request,
which lets a test assert what was sent: the key header, the body, the retry
count. Raw socket fakes cover resets and connections closed mid-answer. As
their design notes say, anthropic and gemini have not yet been run against
the live API, and openai only against a local Ollama.
-->

---

## A fake of your own

```jennifer excerpt
def srv as httpd.Server init httpd.listen("127.0.0.1:" + $port);
while (true) { # lint-disable: L105
    def req as httpd.Request init httpd.accept($srv);
    def path as string init httpd.path($req);
    # ... pick the next scripted answer for this path ...
    httpd.setHeader($req, "Content-Type", "application/json");
    httpd.respond($req, 200, $answer);
}
```

```text
fake: POST /v1/messages (x-api-key) -> 429, retry-after 30
fake: POST /v1/chat/completions (Authorization) -> 200, 140 bytes in
fake: POST /v1beta/models/gemini-3.8-flash:generateContent ...
```

<!-- notes:
The trailing lint-disable comment silences L105, jennifer lint's warning for a
loop whose condition is always true: this server loop is meant to run until
the process is stopped.
The fake behind this talk serves all three paths with scripted answers:
a text reply, a tool-call reply, the final answer, and a 429 for one model. It logs
which key header arrived, never its value. Start it on a free port, set the
three base URL variables and the keys to obviously fake values, and the same
programs run offline. A 429 or a malformed body is one more scripted answer.
-->

---

## Read more

- [deckyard/deck-anthropic](https://registry.jennifer-lang.dev/deck/deckyard/anthropic):
  thinking, effort, caching, batches, token counting
- [deckyard/deck-openai](https://registry.jennifer-lang.dev/deck/deckyard/openai):
  compatible servers, structured output, embeddings
- [deckyard/deck-gemini](https://registry.jennifer-lang.dev/deck/deckyard/gemini):
  files, context caching, embeddings, thinking levels
- Each deck's `docs/design.md`: scope, limits, what is not covered yet
- The language: [jennifer-lang.dev](https://jennifer-lang.dev/), the
  [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
Not covered here: embeddings, which openai and gemini both offer; Gemini's
file uploads and context caches; Anthropic's prompt caching and batches;
structured output in all three. The design notes in each repository say what
is out of scope, such as streaming and OpenAI's Responses API, and why. Each
deck's call function reaches any endpoint the helpers do not cover yet.
-->

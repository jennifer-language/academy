# Talking to LLMs from Jennifer: the code

The programs behind the slides. They use the `@deckyard/anthropic`,
`@deckyard/openai` and `@deckyard/gemini` decks, listed in `deck.toml`, so
run `jvc install` once in this folder to fill `vendor/`. Run everything from
this folder with Jennifer 0.26.0.

Nothing here was run against a vendor, and no real key was used. `fake.j`
stands in for all three APIs on one loopback port, and every program reads
a base URL variable (`ANTHROPIC_BASE_URL`, `OPENAI_BASE_URL`,
`GEMINI_BASE_URL`) that points it there. `env.sh` sets those and
placeholder keys (`sk-ant-FAKE-KEY`, `sk-FAKE-KEY`, `FAKE-KEY`), which the
fake accepts without looking at them.

To run a program against the real API instead, leave the base URL unset
and export a real key from your secret store, for example
`ANTHROPIC_API_KEY=sk-ant-REPLACE-ME jennifer run claude.j`. That costs
money and was not done for this talk.

- `deck.toml`: the jvc manifest with the three decks ("Setup: the key comes
  from the environment").
- `fake.j`: the fake APIs: `/v1/messages`, `.../chat/completions` and
  `/v1beta/models/<id>:generateContent`. It answers from the request: a text
  reply, a tool-call reply (three `stock_level` calls) when tools are
  declared, the final answer once tool results come back, and a 429 with
  `retry-after: 30` for the model `fake-429`. It logs which key header
  arrived, never its value ("A fake of your own", "Tools: what happened").
  Run: `jennifer run fake.j 28800 &`
- `env.sh`: placeholder keys and the base URLs of the fake.
  Use: `. ./env.sh`
- `claude.j`: "A first message: Claude", plus the `ANTHROPIC_BASE_URL`
  lines from "Testing without a key". Run: `jennifer run claude.j`
- `gpt.j`, `gemini.j`: "The same in GPT and Gemini".
  Run: `jennifer run gpt.j`, `jennifer run gemini.j`
- `wire.j`: prints the three requests as JSON ("What actually goes on the
  wire"). Needs no key and no server. Run: `jennifer run wire.j`
- `reply.j`: stop reasons and `Usage` from all three ("Reading a reply").
  Run: `jennifer run reply.j`
- `conversation.j`: Gemini, a question and a follow-up with `addReply`
  ("A conversation: addReply"). Run: `jennifer run conversation.j`
- `tools.j`: declares `stock_level` and runs the tool loop with a stock
  table as the context ("Tools: declare them", "Tools: the loop", "Tools:
  what happened"). The argument picks the deck.
  Run: `jennifer run tools.j anthropic` (or `openai`, `gemini`)
- `errors.j`: a 429 from each vendor with the retries switched off, read
  from the error struct ("Errors: match the kind, then read fields").
  Run: `jennifer run errors.j`
- `local.j`: an OpenAI-compatible server on `127.0.0.1:11434` with no key,
  the plain-http refusal for another host, and Azure when
  `AZURE_OPENAI_ENDPOINT` and `AZURE_OPENAI_KEY` are set ("OpenAI-compatible
  servers"). It was run with a second copy of the fake on port 11434 in
  place of Ollama: `jennifer run fake.j 11434 &`. With a real Ollama,
  `ollama pull qwen3:4b` first.
  Azure (placeholders): `AZURE_OPENAI_ENDPOINT=https://NAME.openai.azure.com AZURE_OPENAI_KEY=REPLACE-ME jennifer run local.j`
- `run.sh`: starts the fake on 28800 and 11434, runs every program above
  with `env.sh`, stops the fakes and prints their log. Run: `./run.sh`

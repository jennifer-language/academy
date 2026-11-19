# Alerting with Gotify, Telegram, Slack and Discord: the code

The programs behind the slides. They use the `@jennifer/gotify`,
`@jennifer/telegram`, `@jennifer/slack` and `@jennifer/discord` decks, listed
in `deck.toml`, so run `jvc install` once in this folder to fill `vendor/`.
Run everything from this folder with Jennifer 0.26.0.

Nothing here talks to the real services: `mock.j` stands in for all four on
`127.0.0.1:28790`, and `.env.test` points every channel at it. The tokens and
webhook URLs in the `.env.*` files are placeholders.

- `deck.toml`: the jvc manifest with the four decks ("Set up").
- `alerts.j`: the module behind most slides. One `Alert`, routed to every
  configured channel; priority, chat id and parse mode, Block Kit, embeds;
  retries on 429 with `Retry-After` and Telegram's `retry_after`; an
  `AlertError` when a channel gives up ("Gotify: the priority is the
  urgency", "Telegram: chat ids and parse modes", "Slack: an Incoming Webhook
  and Block Kit", "Discord: webhooks and embeds", "One alert, routed by
  severity", "Fan out: one broken channel must not stop the rest", "Rate
  limits: 429 and Retry-After", "Telegram's flood control, in the same loop").
  It is a module; `once.j` and `diskcheck.j` import it.
- `mock.j`: the fake Gotify, Telegram, Slack and Discord on one port. It logs
  every request and, with `MOCK_LIMIT=slack` (or `discord`, `telegram`,
  `gotify`), answers the first request to that service with a 429 ("Testing
  alerts against a mock server", "What Slack and Discord received").
  Run: `jennifer run mock.j 28790 &`
- `once.j`: sends one critical alert to every configured channel, with the
  settings from `.env` files ("Keep the secrets out of the code").
  Run, with the mock running:
  `JENNIFER_ENV=test MOCK_LIMIT=slack jennifer run once.j`
- `.env.test`: every channel pointed at the mock. `.env.broken`: every
  channel broken in a different way, for "What each deck throws".
  Run: `JENNIFER_ENV=broken jennifer run once.j` (with the mock running).
- `run.sh`: starts the mock, runs one program, stops the mock and prints its
  log. Example: `JENNIFER_ENV=test ./run.sh once.j`
- `diskcheck.j`: alerts once when a filesystem crosses a threshold and once
  when it recovers, keeping the last state in `diskcheck.state` ("A disk check
  that alerts once", "Four runs"). Needs `df` (the `exec` capability).
  Run, with the mock running:
  `JENNIFER_ENV=test jennifer run diskcheck.j / 80 90`
- `alerts_test.j`: unit tests with an in-process fake server on a free port
  ("The same idea as unit tests").
  Run: `jennifer test alerts_test.j`

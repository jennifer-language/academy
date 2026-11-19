# How to code a Telegram bot with Jennifer: the code

The dice bot behind the slides and the fake Bot API it was run against. The
bot uses the `@jennifer/telegram` deck, listed in `deck.toml`, so run
`jvc install` once in this folder to fill `vendor/`. Run everything from this
folder with Jennifer 0.26.0.

Nothing here talks to the real Telegram: `fake-telegram.j` stands in for the
Bot API on a loopback port, and the bot is pointed at it with
`TELEGRAM_API`. The token `123456:TEST-TOKEN` is a placeholder the fake
accepts; any other token gets a 401.

- `deck.toml`: the jvc manifest with `@jennifer/telegram` ("Set up").
- `bot.j`: the whole bot. getMe and the token check ("First contact:
  getMe"), the poll loop and the offset ("The loop and the offset"), the
  commands ("Commands: match on the first word"), the checked `/roll`
  ("/roll: never trust the input"), the inline keyboard and button presses
  ("Buttons and callback queries"), `sendLogo` ("Sending a photo or a
  file"), `reply` with flood control ("Errors: a struct, flood control, no
  token in logs"), the SIGTERM stop with the final poll ("Run it as a
  service, stop it cleanly") and `TELEGRAM_API` ("Test without Telegram").
  It logs each update as `<- id command`, and plain text only as `text`.
  `DICE_SEED` (optional) seeds the dice so a run can be repeated.
  Run against the real API (a token from @BotFather, never in git):
  `TELEGRAM_BOT_TOKEN=123456:REPLACE-ME jennifer run bot.j`
- `fake-telegram.j`: the fake Bot API on `httpd`. It checks the token in
  the path, hands out six scripted updates (`/start`, a press of "Roll 2d6",
  `/roll 3d20`, `/roll 900d6`, `/logo`, `hello`), three per `getUpdates`,
  logs every call as `tg: ...`, and answers the fifth `sendMessage` with a
  429 and `retry_after` 2. An empty poll is held 3 seconds instead of the
  full timeout ("What Telegram saw", "Test without Telegram").
  Run: `jennifer run fake-telegram.j 28780 &`, then
  `TELEGRAM_BOT_TOKEN=123456:TEST-TOKEN TELEGRAM_API=http://127.0.0.1:28780 jennifer run bot.j`
- `run.sh`: starts the fake, runs the bot with `DICE_SEED=649591` (the rolls
  on the slides), stops it with SIGTERM after 10 seconds and prints both
  logs; the bot ends with `stopped, next offset 7`.
  Run: `./run.sh` (or `./run.sh 30` for a longer run)
- `jennifer-logo.png`: the picture `/logo` uploads (5894 bytes on the wire
  with the form around it).
- `dicebot.service.ini`: the systemd unit from "Run it as a service", with
  `[Unit]` and `[Install]` added; install it as
  `/etc/systemd/system/dicebot.service` with the token in
  `/etc/dicebot.env` (`TELEGRAM_BOT_TOKEN=123456:REPLACE-ME`).

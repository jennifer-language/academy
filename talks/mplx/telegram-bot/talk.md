---
theme: nordic
ratio: 16:9
transition: slide
---

# How to code a Telegram™ bot with Jennifer

![Jennifer](jennifer-logo.png)

A complete interactive bot in one short program: commands, buttons, photos,
flood control, and a clean stop, with the `@deckyard/telegram` deck.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
We build a dice bot: it answers /start with buttons, rolls dice on /roll 2d6,
sends a picture on /logo, and survives Telegram™'s rate limits. The whole
program is about 170 lines. Every output on these slides is from a real run,
against a fake Bot API server on a loopback port, so it can be repeated on a
laptop without an account; the last slides show how that works.
-->

---

## Long polling: why it fits in one program

- The bot **asks** Telegram for updates: `getUpdates`, waiting up to 25 s
- No public HTTPS endpoint, no certificate, no open port: runs behind NAT
- Nothing to verify: the bot talks only to Telegram, over HTTPS
- One loop, one process; the state is a single number, the **offset**

The alternative, a webhook, is on the last slide.

<!-- notes:
There are two ways to receive messages. With a webhook, Telegram calls you,
so you need a public HTTPS server and must check that each request really
comes from Telegram. With long polling you call Telegram and the request
simply stays open until something happens or the timeout passes. For a bot
on a home server, a Raspberry Pi™ or a laptop, that is the simple choice, and
it is the one the deck supports.
-->

---

## Set up

1. In Telegram, talk to **@BotFather**: `/newbot`, a name, a username
2. It answers with a token like `123456:ABC-...`: a password, treat it as one
3. Add the deck:

```sh
jvc add @deckyard/telegram     # records it in deck.toml
jvc install                    # into vendor/deckyard/telegram/
export TELEGRAM_BOT_TOKEN=...  # from a secret store, never in git
```

```jennifer
import "@deckyard/telegram/" as telegram;
```

<!-- notes:
BotFather is Telegram's own bot for making bots. Besides the token it lets
you set the description, the profile picture and the command list users see
when they type a slash. The token is the bot's whole identity: whoever has it
can read the bot's messages and send in its name. So it lives in the
environment, filled from a secret store or a systemd credential, and never in
the repository. If it leaks, BotFather's /revoke issues a new one.
-->

---

## First contact: getMe

```jennifer excerpt
def token as string init os.getEnv("TELEGRAM_BOT_TOKEN");
if ($token == "") {
    io.eprintf("bot: set TELEGRAM_BOT_TOKEN\n");
    exit 2;
}
def b as telegram.Bot init telegram.bot($token);
def me as telegram.User init telegram.getMe($b);
io.printf("running as @%s\n", $me.username);
```

```text
running as @jennifer_dice_bot
```

<!-- notes:
A Bot is just the token and the API's base URL, a plain value. getMe is the
cheapest call there is and the right first one: it proves the token works and
tells you the bot's username. A wrong token fails right here with a
TelegramError, error code 401, before the bot pretends to be running. Exit
code 2 for a missing setting lets a service manager tell a configuration error
from a crash.
-->

---

## The loop and the offset

```jennifer excerpt
try {                                   # in the while loop
    $updates = telegram.getUpdatesRaw($b, $offset, POLL_SECONDS);
} catch (e) {
    def why as string init telegram.redactToken($e.message, $token);
    io.printf("poll failed (%s): %s\n", $e.kind, $why);
    time.sleep(time.fromSeconds(5));
}
for (def raw in $updates) {
    $offset = telegram.parseUpdate($raw).updateId + 1;
    handle($b, $raw);    # try { onUpdate(...) } catch: log, go on
}
```

<!-- notes:
Every update has an increasing id. Asking with offset = last id + 1 tells
Telegram that everything before it is done, so it is not delivered again. The
deck keeps no state; the offset is yours. getUpdatesRaw returns each update as
JSON, because getUpdates keeps only text messages and we also want button
presses. A failed poll, a network error or a timeout, is logged and retried
after five seconds; the offset starts at 0. handle runs one update inside a
try: a failure is logged and skipped, so one bad message cannot stop the bot.
-->

---

## What Telegram saw

```text
tg: getUpdates offset=0 timeout=25 -> 3 update(s)
tg: sendMessage chat=42 +keyboard "Hi! Pick a roll:"
tg: answerCallbackQuery cb2
tg: sendMessage chat=42 "2d6: 4 + 5 = 9"
tg: sendMessage chat=42 "3d20: 13 + 20 + 2 = 35"
tg: getUpdates offset=4 timeout=25 -> 3 update(s)
tg: sendMessage chat=42 "1 to 20 dice, 2 to 1000 sides."
tg: sendChatAction upload_photo
tg: sendPhoto multipart, 5894 bytes
tg: getUpdates offset=7 timeout=25 -> 0 update(s)
```

<!-- notes:
This is the fake server's log of the run: three updates per batch, the offset
moving from 0 to 4 to 7, and every answer the bot sent. The scripted user
pressed /start, then a button, then sent /roll 3d20, /roll 900d6, /logo and a
plain hello. Two lines about the hello and the rate limit are left out here;
they come back on the errors slide. After the last batch the bot keeps
polling with offset 7 and gets nothing until someone writes.
-->

---

## Commands: match on the first word

```jennifer excerpt
def cmd as string init strings.split($words[0], "@")[0];   # /roll@bot
def id as int init $msg.chatId;
match ($cmd) {
    when "/start" {
        telegram.sendMessageWithKeyboard($b, $id, START, keyboard());
    }
    when "/help" { reply($b, $id, HELP); }
    when "/roll" { reply($b, $id, roll($arg)); }   # 2nd word or 1d6
    when "/logo" { sendLogo($b, $id); }
    else { reply($b, $id, HELP); }
}
```

<!-- notes:
A command is a message that starts with a slash. The handler splits the text
on blanks into words, with regex.split; the first word is the command. In groups Telegram appends
the bot's name, /roll@jennifer_dice_bot, so we cut at the @. match compares
the first word with each arm and has no fall-through. /roll takes its
argument or 1d6, /logo is the photo upload two slides on, and reply is a
small helper around sendMessage that we meet on the errors slide. Anything unknown gets the help text, which is friendlier than
silence.
-->

---

## /roll: never trust the input

```jennifer excerpt
if (not regex.matches('^[0-9]{1,4}d[0-9]{1,4}$', $spec)) {
    return "Write it like /roll 2d6.";
}
def parts as list of string init strings.split($spec, "d");
def n as int init convert.toInt($parts[0]);
def sides as int init convert.toInt($parts[1]);
if ($n < 1 or $n > 20 or $sides < 2 or $sides > 1000) {
    return "1 to 20 dice, 2 to 1000 sides.";
}
```

```text
<- 3 /roll 3d20       ->  3d20: 13 + 20 + 2 = 35
<- 4 /roll 900d6      ->  1 to 20 dice, 2 to 1000 sides.
```

<!-- notes:
A bot is a public interface: anyone who finds it can send it anything. So the
argument is checked by shape first, with a regular expression in a raw string,
and then by range, before a single die is rolled. Without the cap,
/roll 9999d9999 would build a message far over Telegram's 4096-character limit
and the send would fail. The lines underneath pair what came in with what went
out, from the bot's log and the server's.
-->

---

## Buttons and callback queries

```jennifer excerpt
[[telegram.inlineButton("Roll 1d6", "roll:1d6"),
  telegram.inlineButton("Roll 2d6", "roll:2d6")],
 [telegram.urlButton("Jennifer", "https://jennifer-lang.dev/")]]
```

```jennifer excerpt
def q as telegram.CallbackQuery init telegram.parseCallbackQuery($raw);
telegram.answerCallbackQuery($b, $q.id, "");
# CallbackQuery has no chat id; read it from the raw update
def chat as int init json.asInt($raw, CHAT_ID);   # its JSON Pointer
if (strings.startsWith($q.data, "roll:")) {
    reply($b, $chat, roll($q.data[5..]));
}
```

<!-- notes:
An inline keyboard is a list of rows of buttons, plain values: two callback
buttons in the first row, a link in the second. A callback button carries up to 64 bytes of data back to the bot when pressed; here the
data is the roll itself. The press arrives as an update without a message, so
we read it from the raw JSON with parseCallbackQuery. Always answer it, even
with an empty text: until you do, the user's client shows a spinner on the
button. One gap in the deck: the parsed query does not carry the chat id, so
we read that one field from the JSON ourselves.
-->

---

## Sending a photo or a file

```jennifer
func sendLogo(b as telegram.Bot, chatId as int) {
    telegram.sendChatAction($b, $chatId, "upload_photo");
    telegram.sendPhotoFile($b, $chatId, "jennifer-logo.png", "image/png");
}
```

```text
<- 5 /logo
tg: sendChatAction upload_photo
tg: sendPhoto multipart, 5894 bytes
```

- `sendPhoto(b, chat, urlOrFileId, caption)`: no upload, Telegram fetches it
- `sendDocumentFile(b, chat, path, contentType)`: any file, as a document

<!-- notes:
The chat action shows "sending photo..." in the user's client while the
upload runs. sendPhotoFile reads the file and posts it as multipart form data,
as raw bytes so a binary file arrives intact; the server saw a 5894-byte body
for a 5.5 kilobyte PNG plus the form around it. For a file Telegram already
has, pass its file id to sendPhoto instead and nothing is uploaded again.
-->

---

## Errors: a struct, flood control, no token in logs

```jennifer excerpt
try {                                 # in reply(), up to three times
    return telegram.sendMessage($b, $chatId, $text);
} catch (e) {
    if ($e.kind != "telegram" or $e.retryAfter == 0) { throw $e; }
    io.printf("flood control: wait %d s\n", $e.retryAfter);
    time.sleep(time.fromSeconds($e.retryAfter));
}
```

```text
<- 6 text
tg: sendMessage -> 429
flood control: wait 2 s
tg: sendMessage chat=42 "I know /start, /help, /roll 2d6 and /logo."
```

`TelegramError`: `errorCode`, `retryAfter`, `migrateToChatId`, `status`

<!-- notes:
Every API error is one struct, kind "telegram", with Telegram's error code and
its parameters as fields. Under flood control the reply is 429 with
retry_after, and the right reaction is to wait exactly that long: the reply
helper does, up to three times, then gives up with kind "limit". Check the
kind before reading a field. Network failures stay net.NetError, kind "net".
The token is part of every request URL, so the deck strips it from every error
it throws, and redactToken does the same for your own log lines.
-->

---

## Run it as a service, stop it cleanly

```ini
[Service]
ExecStart=/usr/bin/jennifer run /opt/dicebot/bot.j
WorkingDirectory=/opt/dicebot
EnvironmentFile=/etc/dicebot.env
DynamicUser=yes
Restart=on-failure
```

```jennifer excerpt
os.catchSignal("term");          # before the loop
if (os.gotSignal("term") or os.gotSignal("int")) { $running = false; }
telegram.getUpdatesRaw($b, $offset, 0);   # after it, in a try
```

<!-- notes:
A systemd unit is enough: the token in an environment file readable only by
root, a throwaway user, and a restart when it crashes; add an [Install]
section with WantedBy=multi-user.target to start it at boot. On systemctl stop the
bot gets SIGTERM; it finishes the current batch, at most one long poll later,
and leaves the loop. The last poll with timeout 0 tells Telegram that the
final batch is done; without it the bot would see those updates again after a
restart. Our run ended with "stopped, next offset 7". The container image
works the same way: docker stop sends SIGTERM too.
-->

---

## Test without Telegram

```jennifer excerpt
def b as telegram.Bot init telegram.bot($token);
if (os.getEnv("TELEGRAM_API") != "") {
    $b = telegram.botWith($token, os.getEnv("TELEGRAM_API"));
}
```

```text
$ jennifer run fake-telegram.j 28780 &
$ TELEGRAM_BOT_TOKEN=123456:TEST-TOKEN \
  TELEGRAM_API=http://127.0.0.1:28780 jennifer run bot.j
running as @jennifer_dice_bot
```

A fake Bot API in 146 lines: `httpd`, scripted updates, one 429.

<!-- notes:
botWith points the bot at any base URL: a self-hosted Bot API server, or a
test server. The fake used for this talk is a Jennifer program on httpd: it
checks the token in the path, hands out six scripted updates by offset, logs
each call, and answers one sendMessage with a 429 to exercise the retry. Plain
http is fine on loopback; against the real API the default base URL is https.
The deck's own tests work the same way.
-->

---

## Webhooks, gaps, and read more

- **Webhook instead of polling:** when the bot already sits behind a public HTTPS
  server or must scale to many messages. The deck does not register webhooks;
  `telegram.parseUpdate` reads the same JSON in a `web` handler.
- **Not yet in the deck:** the chat id of a button press, editing a sent
  message, the sender of a message (all reachable through the raw JSON)
- The deck: [deckyard/deck-telegram](https://registry.jennifer-lang.dev/deck/deckyard/telegram)
- The language: [jennifer-lang.dev](https://jennifer-lang.dev/), this talk in
  the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.27.0, November 2026.

<!-- notes:
A webhook removes the polling connection and delivers each update as an HTTPS
request to you, which pays off for busy bots. It needs a public address with a
valid certificate, a setWebhook call, which the deck does not wrap, and a
check of the secret token header Telegram sends. Polling and webhooks are
exclusive: a bot with a webhook set gets nothing from getUpdates. The gaps
listed are small; each is one more field or one more call through the deck's
request core.
-->

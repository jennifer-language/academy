---
theme: ember
ratio: 16:9
transition: slide
---

# Notifications and alerting with Jennifer

![Jennifer](jennifer-logo.png)

One alert, four channels: Gotify, Telegram, Slack and Discord, sent once when
something breaks and once when it is fixed.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
This talk builds a small alerting layer: four decks that send messages, one
function that sends an alert to all of them, retries for rate limits, and a
disk check that alerts once and reports the recovery. Every request and every
output on the slides is from a real run against a fake server on a loopback
port, so nothing here needs an account or a token, and no message left the
laptop. The last slides show how that mock server works.
-->

---

## What makes a good alert

- **Who** has to act? Send it to them, not to everyone
- **How urgent?** Critical wakes someone, a warning can wait, the rest is a log line
- **Once:** a problem alerts when it starts, not on every check
- **And once more** when it is over: "resolved"
- **Actionable:** what, where, how bad, and the limit it crossed
- **Never silent:** if one channel is down, the others still get it

<!-- notes:
Most alerting goes wrong the same way: a check runs every five minutes and
sends a message every five minutes, people mute the channel, and the one alert
that matters is missed. So the program we write remembers what it already
said. It sends when the state changes: from fine to warning, from warning to
critical, and back to fine. Each message says which machine, which path, the
number and the limit, so whoever reads it at night knows what to do without
opening a dashboard first.
-->

---

## Four decks, four ways to deliver

| Deck | Sends to | The secret | Success |
| --- | --- | --- | --- |
| `@jennifer/gotify` 0.1.0 | your Gotify server | app token, a header | `200` |
| `@jennifer/telegram` 0.2.0 | the Telegram Bot API | bot token, in the URL path | a `Message` |
| `@jennifer/slack` 0.1.0 | an Incoming Webhook | the webhook URL | `200 ok` |
| `@jennifer/discord` 0.1.0 | a channel webhook | the webhook URL | `204` |

The bundled modules `gotify.j`, `telegram.j`, `slack.j` and `discord.j` are
deprecated since 0.26.0 and **removed in 0.28.0**: use the decks.

<!-- notes:
Gotify is a push server you host yourself, with phone apps; it is the one
channel that does not depend on someone else's cloud. Telegram is a chat, so
alerts reach a phone everywhere. Slack and Discord are where teams already
talk. The versions are the ones in the registry today. All four started as
bundled Jennifer modules; they moved out into decks so they can be released
on their own schedule. The decks keep the same functions, so moving over is
a change of one import line, shown on the next slide.
-->

---

## Set up

```sh
jvc add @jennifer/gotify
jvc add @jennifer/telegram
jvc add @jennifer/slack
jvc add @jennifer/discord
jvc install            # copies each deck into vendor/jennifer/<deck>/
```

```jennifer excerpt
import "slack.j" as slack;              # before: bundled, deprecated
import "@jennifer/slack/" as slack;     # after: the deck
```

<!-- notes:
jvc records the four requirements in deck.toml, resolves them against the
registry, pins them in camcorder.lock and copies their sources into vendor.
The trailing slash in the import means the deck's entry module. Two small
differences from the old modules: the Slack and Discord decks refuse a webhook
URL that is not https, so the secret is never sent in the clear, and Slack
gains an escape function. A plain http URL is allowed only to a loopback
address, which is what makes the mock server possible.
-->

---

## Gotify: the priority is the urgency

```jennifer excerpt
func priority(severity as string) {
    match ($severity) {
        when "critical" { return 8; }
        when "warning" { return 5; }
        else { return 2; }
    }
}
def g as gotify.Config init gotify.Config{
    url: os.getEnv("GOTIFY_URL"), token: os.getEnv("GOTIFY_TOKEN")};
def r as http.Response init gotify.push($g, $title, $text,
    priority($sev));
```

```text
POST /gotify/message   X-Gotify-Key: AbCdEf123456789
  title=/srv is 96% full   priority=8
```

<!-- notes:
push sends a form with title, message and priority to the server's /message
path, with the application token in the X-Gotify-Key header. In Gotify's
Android app the priority decides how loud the notification is: zero shows
nothing, low numbers are quiet, from four up it makes a sound, and eight and
up is the loud end. So severity maps straight to priority. pushMarkdown renders
the body as Markdown, and pushWith adds a URL that opens when the
notification is tapped, for a link to a runbook. The output is the mock's log,
two lines joined to fit.
-->

---

## Telegram: chat ids and parse modes

- The chat id is an `int`: a user is positive, a group negative,
  a supergroup or channel `-100...`
- A bot cannot write first: `/start` it, or add it to the group
- Parse mode: `""` plain, `"HTML"`, `"MarkdownV2"`, legacy `"Markdown"`

```jennifer excerpt
def html as string init "<b>" + htmlEscape($a.title) + "</b>\n" +
    htmlEscape($a.text);     # &, < and > as entities
telegram.sendMessageWith($c.bot, $c.chatId, $html, "HTML");
```

```text
  text=<b>/srv is 96% full</b>
       38 GiB free, limit 90%.
       Top: backup &lt;daily&gt;
  parse_mode=HTML
```

<!-- notes:
To find a chat id, write to the bot and read the update with getUpdatesRaw;
the Telegram bot talk in this academy shows that loop. The deck takes the id
as an int, so a public channel's @name does not work here, its numeric id
does. HTML is the easiest parse mode for alerts: only three characters need
escaping, while MarkdownV2 reserves eighteen. Escape everything that comes from
elsewhere, here a job name in angle brackets, or Telegram rejects the whole
message with a 400. The mock shows the form field with its line breaks.
-->

---

## Slack: an Incoming Webhook and Block Kit

- **Incoming Webhook:** one URL per channel; the URL is the whole secret
- **Web API** (`chat.postMessage`, threads, edits): not in the deck
- Blocks: `header`, `section`, `fieldsSection`, `contextBlock`,
  `actionsBlock` with `button`, `divider`

```jennifer excerpt
def m as slack.Message init slack.text(slack.message(), $a.title);
$m = slack.header($m, $a.title);
$m = slack.section($m, slack.escape($a.text));
$m = slack.contextBlock($m, "key `" + slack.escape($a.key) + "`");
def r as http.Response init slack.sendMessage($c.slackUrl, $m);
```

<!-- notes:
A webhook is created in a Slack app and is bound to one channel; it can only
post. That is exactly what an alert needs, without a bot token or OAuth. For
threads, editing a message or reading a channel you need the Web API with a
bot token, which the deck leaves out; the http module can call it directly.
text is the fallback that shows in the phone notification, the blocks are
what the channel shows. escape turns ampersand, less-than and greater-than
into entities, so a stray <!channel> in a log line pings nobody.
-->

---

## Discord: webhooks and embeds

- Channel settings, Integrations, Webhooks: copy the URL, the secret
- An **embed** is a card: title, description, colour bar, fields, footer
- `noMentions`: an `@everyone` inside the text pings nobody

```jennifer excerpt
def m as discord.Message init discord.noMentions(discord.message());
$m = discord.embed($m, $a.title, $a.text, colour($a.severity));
$m = discord.embedFooter($m, $a.key);
def r as http.Response init discord.sendMessage($c.discordUrl, $m);
```

Colours are decimal RGB: `15158332` is `0xE74C3C`, red.

<!-- notes:
A Discord webhook also posts into one channel, and Discord answers 204 with
an empty body. embed adds a card; embedField adds name and value pairs to the
last card, embedFooter and embedAuthor small lines around it. The colour must
be between zero and 16777215, or embed throws kind discord before anything is
sent. noMentions sets allowed_mentions to an empty list, which matters as soon
as any text in the alert comes from a log file or a user. username and avatar
override how the webhook appears for one message.
-->

---

## What Slack and Discord received

```text
POST /slack/services/T000/B000/XXXX
{"text":"/srv is 96% full","blocks":[{"type":"header","text":
  {"type":"plain_text","text":"/srv is 96% full"}},{"type":"section",
  "text":{"type":"mrkdwn","text":"38 GiB free, limit 90%.\nTop: backup
  \u0026lt;daily\u0026gt;"}},{"type":"context","elements":[{"type":
  "mrkdwn","text":"key `disk:/srv`"}]}]}
POST /discord/api/webhooks/42/XXXX
{"embeds":[{"title":"/srv is 96% full","description":"38 GiB free,
  limit 90%.\nTop: backup \u003cdaily\u003e","color":15158332,
  "footer":{"text":"disk:/srv"}}],"allowed_mentions":{"parse":[]}}
```

<!-- notes:
These are the bodies as the mock received them, each one line of JSON,
wrapped here to fit the slide. Note the escaping in two layers on the Slack
side: slack.escape turned the angle brackets into the entities &lt; and &gt;,
and the JSON encoder writes the ampersand as \u0026, which Slack decodes
again, so the channel shows the job name in angle brackets. The Discord deck
has no escape function and sends the brackets as they are, JSON-encoded as
\u003c and \u003e; noMentions makes sure text like <@id> pings nobody.
-->

---

## One alert, routed by severity

```jennifer excerpt
export def struct Alert {
    key as string,        # names the problem: "disk:/srv"
    severity as string,   # "critical", "warning" or "ok"
    title as string,      # one line
    text as string        # the details
};
```

| Severity | Gotify priority | Discord colour | Telegram, Slack |
| --- | --- | --- | --- |
| critical | 8 | `15158332` red | bold title, details |
| warning | 5 | `15105570` orange | the same |
| ok (resolved) | 2 | `3066993` green | the same |

<!-- notes:
The rest of the program never talks to a deck directly. It builds an Alert,
and a module of about two hundred lines, alerts.j, turns it into each
channel's format. The key is the most important field: it names the problem,
not the message, so the program can tell that the disk alert of this morning
and the one of this afternoon are the same problem. Routing by audience fits
here too: send warnings only to the team chat and critical alerts also to the
phone, with one condition in the function that lists the channels.
-->

---

## Fan out: one broken channel must not stop the rest

```jennifer excerpt
for (def ch in enabled($c)) {     # in notify: the configured ones
    try {
        deliver($c, $a, $ch);
    } catch (e) {
        $failed[] = "{$ch}: [{$e.kind}] {$e.message}";
    }
}
```

```text
gotify: [net] net.connect: 127.0.0.1:28799: dial tcp
  127.0.0.1:28799: connect: connection refused
telegram: [telegram] telegram: Unauthorized
slack: [slack] slack: the webhook URL must start with https://
discord: [alert] discord: HTTP 404
```

<!-- notes:
Every channel gets its own try, so a dead Gotify server does not keep the
alert from Slack. This run used a second settings file in which each channel is
broken in a different way: nothing listening on the Gotify port, a wrong bot
token, a plain http Slack URL to a host that is not loopback, and a Discord
webhook path the mock does not know. The first line is wrapped to fit. The
caller decides what to do with the list; the disk check exits with 1 only
when every channel failed.
-->

---

## What each deck throws

| | gotify, slack, discord | telegram |
| --- | --- | --- |
| `2xx` | returns the `http.Response` | returns the `Message` |
| `4xx`, `5xx`, `429` | returned too: **check `$r.status`** | throws `TelegramError` |
| bad URL | slack, discord: kind `slack` / `discord` | - |
| network | `net.NetError`, kind `net` | kind `net`, token removed |

`TelegramError`: `kind`, `message`, `errorCode`, `retryAfter`,
`migrateToChatId`, `status`. Match the **kind**, never the message.

<!-- notes:
The three webhook decks return the response and do not judge it: a revoked
Slack webhook is a 404 response, not an exception. Forgetting to check the
status is the classic silent failure, so deliver turns every non-2xx answer
into an AlertError struct of its own, with the channel and the status as
fields. Telegram's API answers in JSON with ok false, and the deck throws one
TelegramError for every API error, with the token stripped from every message.
Network failures are http's net.NetError everywhere. Read struct fields only
after the kind matched.
-->

---

## Rate limits: 429 and Retry-After

```jennifer excerpt
for (def attempt in 1..MAX_TRIES + 1) {
    def got as list of int init sendOnce($c, $a, $ch); # status, wait
    $status = $got[0];
    if ($status >= 200 and $status < 300) {
        return;
    }
    if ($status != 429 or $attempt == MAX_TRIES) {
        break;
    }
    io.printf("%s: 429, retry in %d s\n", $ch, $got[1]); # <= 60
    time.sleep(time.fromSeconds($got[1]));
}
throw AlertError{...};     # kind "alert", the channel, the status
```

<!-- notes:
Every chat service limits how fast you may post. Telegram allows about one
message per second per chat, Slack about one per second per webhook, and
Discord counts per webhook. All three answer 429 and say how long to wait.
Slack and Discord send a Retry-After header in seconds, Discord also a
retry_after field in the JSON body. The decks do not retry; this loop does,
at most three tries, waiting exactly as long as the server asked, capped at
sixty seconds. After the last try it throws, and notify records the failure.
-->

---

## Telegram's flood control, in the same loop

```jennifer excerpt
try {                                   # in sendOnce
    toTelegram($c, $a);
    return [200, 0];
} catch (e) {
    if ($e.kind != "telegram" or $e.retryAfter == 0) {
        throw $e;
    }
    return [429, $e.retryAfter];
}
```

```text
POST /tg/bot123456:TEST-TOKEN/sendMessage   -> 429
telegram: 429, retry in 2 s
POST /tg/bot123456:TEST-TOKEN/sendMessage
```

<!-- notes:
The Telegram deck throws instead of returning a response, so sendOnce
catches the TelegramError and turns flood control back into a status and a
wait, the same pair the webhook decks produce. The kind is checked first;
only then is retryAfter safe to read. Everything else is thrown on. The output
merges the mock's log with the program's: the mock answered the first
sendMessage with a 429 and retry_after 2, the loop waited two seconds and the
second try went through; the mock's two lines for the 429 are joined. The
same run with Slack or Discord limited looks alike.
-->

---

## Keep the secrets out of the code

```jennifer excerpt
dotenv.autoload(os.cwd());   # .env, .env.local, .env.<JENNIFER_ENV>
def c as alerts.Channels init alerts.fromEnv();   # os.getEnv(...)
```

```sh
# .env.test: every service is the mock on 127.0.0.1:28790
SLACK_WEBHOOK_URL=http://127.0.0.1:28790/slack/services/T000/B000/XXXX
TELEGRAM_API=http://127.0.0.1:28790/tg
```

```ini
EnvironmentFile=/etc/diskcheck.env    # mode 0600; a real variable wins
```

<!-- notes:
Four secrets: the Gotify token, the bot token, and two webhook URLs, which are
secrets in full because whoever has the URL can post. None of them belongs in
the repository. dotenv.autoload reads .env, .env.local and the file for the
profile named in JENNIFER_ENV, and never overrides a variable that is already
set, so on the server systemd's EnvironmentFile wins and in a test the
.env.test file points everything at the mock. The Gotify deck does not check
the scheme, so make sure GOTIFY_URL starts with https. Never print the
Channels value: it holds every secret in plain fields.
-->

---

## A disk check that alerts once

```jennifer excerpt
def used as int init usedPercent($path);           # from df -P
def now as string init severity($used, $warn, $crit);
def before as string init stateOf($state, $key);   # "ok" if new
if ($now == $before) {
    exit 0;                               # nothing new: stay quiet
}
...                                       # build the Alert
def failed as list of string init alerts.notify($c, $a);
if (len($failed) == len(alerts.enabled($c))) {
    exit 1;                     # nobody heard it: retry next run
}
$state[$key] = $now;
saveState($state);                        # temp file, then rename
```

<!-- notes:
The check runs from a timer every few minutes. It computes the severity, and
compares it with the last one it reported, kept in a small state file with one
line per key. Same as before: silence. Different: send, and if at least one
channel took it, write the new state, through a temporary file and a rename so
a crash cannot leave half a file. If every channel failed, the state stays and
the next run tries again, so an outage of the alerting path does not swallow
the alert. A resolved alert is just the change back to ok.
-->

---

## Four runs

```text
$ jennifer run diskcheck.j / 80 90
/: 86% used, warning (was ok)
sent warning to 4 channel(s)
$ jennifer run diskcheck.j / 80 90
/: 86% used, warning (was warning)
$ jennifer run diskcheck.j / 80 85
/: 86% used, critical (was warning)
sent critical to 4 channel(s)
$ jennifer run diskcheck.j / 90 95
/: 86% used, ok (was critical)
sent ok to 4 channel(s)
```

<!-- notes:
Filling a real disk for a talk is a bad idea, so the runs move the limits
instead: the two numbers are the warning and the critical percentage. All
four ran with JENNIFER_ENV=test and the mock listening. The
first run warns, the second stays quiet because nothing changed, the third
escalates to critical, the fourth reports the recovery. In that last one the
mock saw Gotify priority 2, a green Discord embed, and the title "Resolved: /
is back to 86%". In production, add a reminder: send again if a critical state
lasts longer than a few hours.
-->

---

## Testing alerts against a mock server

```jennifer excerpt
while (true) { # lint-disable: L105
    def req as httpd.Request init httpd.accept($srv);
    def path as string init httpd.path($req);
    def svc as string init service($path);  # "slack" from /slack/...
    ...                         # log method, path, body; maybe a 429
    match ($svc) {
        when "discord" { httpd.respond($req, 204, ""); }
        ...                     # gotify, slack, tg (or 401), 404
    }
}
```

```sh
jennifer run mock.j 28790 &
JENNIFER_ENV=test MOCK_LIMIT=slack jennifer run once.j
```

<!-- notes:
The trailing lint-disable comment silences L105, jennifer lint's warning for a
loop whose condition is always true: this server loop is meant to run until
the process is stopped.
The mock is one httpd loop that stands in for all four services, told apart
by the first part of the path. It prints the method, path, content type and
body of every request, decodes form bodies, answers the way each service
does, refuses a wrong Telegram token with 401, and with MOCK_LIMIT answers
the first request to one service with a 429. Because the Slack and Discord
decks accept http only for loopback, a test can never send a real webhook
URL in the clear by accident.
-->

---

## The same idea as unit tests

```jennifer excerpt
func testSlack429IsRetried() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    defer httpd.shutdown($srv);
    def t as task of string init spawn {
        answer($srv, 429, "1");       # Retry-After: 1
        return answer($srv, 200, "");
    };
    alerts.deliver(channels($srv), DISK, "slack");
    testing.assertTrue(strings.contains(task.wait($t), "96% full"));
}
```

```text
PASS testCriticalIsPriorityEight (3 ms)
PASS testGivesUpAfterThreeTries (3 ms)
PASS testSlack429IsRetried (1002 ms)
```

<!-- notes:
For jennifer test the fake server runs inside the test: listen on port zero
takes a free port, a spawned task answers the scripted requests and returns
what it saw, and the test points every channel at that address. One test
checks that critical becomes priority 8, one that a 429 is retried after the
second it asked for, which is why it takes a second, and one that three
429s in a row end in an AlertError of kind alert. The decks' own tests work
the same way.
-->

---

## Takeaways and read more

- Alert on a **change** of state, and report the recovery
- Every channel in its own `try`; check `$r.status` on the webhook decks
- Wait as long as a `429` asks; give up after a few tries
- Secrets in the environment, tests against a loopback mock
- Decks: [deck-gotify](https://registry.jennifer-lang.dev/deck/jennifer/gotify),
  [deck-telegram](https://registry.jennifer-lang.dev/deck/jennifer/telegram),
  [deck-slack](https://registry.jennifer-lang.dev/deck/jennifer/slack),
  [deck-discord](https://registry.jennifer-lang.dev/deck/jennifer/discord)
- [The Telegram bot talk](https://academy.jennifer-lang.dev/talks/mplx/telegram-bot/),
  [the registry](https://registry.jennifer-lang.dev/),
  [jennifer-lang.dev](https://jennifer-lang.dev/)

Based on Jennifer 0.27.0, November 2026.

<!-- notes:
The four decks are small on purpose: they format a message and send it, and
leave the policy to you. The policy is what this talk was about: who hears
it, how loud, how often, and what happens when the alerting path itself
fails. If you need a two-way conversation, buttons or commands, the Telegram
bot talk builds that with the same deck. Remember that the bundled modules
disappear in Jennifer 0.28.0, so move the imports to the decks now.
-->

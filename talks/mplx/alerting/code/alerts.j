# One alert, four channels: Gotify, Telegram, Slack, Discord.
# pragma-jennifer-capability: net
use io;
use os;
use strings;
use convert;
use time;
import "http.j" as http;
import "@deckyard/gotify/" as gotify;
import "@deckyard/telegram/" as telegram;
import "@deckyard/slack/" as slack;
import "@deckyard/discord/" as discord;

def const MAX_TRIES as int init 3;
def const MAX_WAIT as int init 60;

/**
 * What happened, how bad it is, and a key that names the problem.
 * @field key {string} stable id of the problem, "disk:/srv"
 * @field severity {string} "critical", "warning" or "ok"
 * @field title {string} one line
 * @field text {string} the details
 */
export def struct Alert {
    key as string,
    severity as string,
    title as string,
    text as string
};

/**
 * Where alerts go; an empty setting switches that channel off.
 * @field gotify {gotify.Config} server URL and app token
 * @field bot {telegram.Bot} bot token and API base
 * @field chatId {int} Telegram chat, 0 for none
 * @field slackUrl {string} Slack Incoming Webhook URL
 * @field discordUrl {string} Discord channel webhook URL
 */
export def struct Channels {
    gotify as gotify.Config,
    bot as telegram.Bot,
    chatId as int,
    slackUrl as string,
    discordUrl as string
};

/**
 * A channel that gave up.
 * @field kind {string} always "alert"
 * @field message {string} what went wrong
 * @field channel {string} gotify, telegram, slack or discord
 * @field status {int} the last HTTP status
 */
export def struct AlertError {
    kind as string,
    message as string,
    channel as string,
    status as int
};

/**
 * The channels, read from the environment.
 * @return {Channels} the settings; unset ones stay empty
 */
export func fromEnv() {
    def c as Channels init Channels{
        gotify: gotify.Config{
            url: os.getEnv("GOTIFY_URL"),
            token: os.getEnv("GOTIFY_TOKEN"),
            allowInsecureHttp: false
        },
        bot: telegram.bot(os.getEnv("TELEGRAM_BOT_TOKEN")),
        chatId: 0,
        slackUrl: os.getEnv("SLACK_WEBHOOK_URL"),
        discordUrl: os.getEnv("DISCORD_WEBHOOK_URL")
    };
    if (os.getEnv("TELEGRAM_API") != "") {
        $c.bot = telegram.botWith($c.bot.token, os.getEnv("TELEGRAM_API"));
    }
    if (os.getEnv("TELEGRAM_CHAT_ID") != "") {
        $c.chatId = convert.toInt(os.getEnv("TELEGRAM_CHAT_ID"));
    }
    return $c;
}

func priority(severity as string) {
    match ($severity) {
        when "critical" { return 8; }
        when "warning" { return 5; }
        else { return 2; }
    }
}

func colour(severity as string) {
    match ($severity) {
        when "critical" { return 15158332; } # 0xE74C3C red
        when "warning" { return 15105570; } # 0xE67E22 orange
        else { return 3066993; } # 0x2ECC71 green
    }
}

func htmlEscape(s as string) {
    def out as string init strings.replace($s, "&", "&amp;");
    $out = strings.replace($out, "<", "&lt;");
    return strings.replace($out, ">", "&gt;");
}

func toGotify(c as Channels, a as Alert) {
    return gotify.push($c.gotify, $a.title, $a.text, priority($a.severity));
}

func toTelegram(c as Channels, a as Alert) {
    def html as string init "<b>" + htmlEscape($a.title) + "</b>\n" + htmlEscape($a.text);
    telegram.sendMessageWith($c.bot, $c.chatId, $html, "HTML");
}

func toSlack(c as Channels, a as Alert) {
    def m as slack.Message init slack.text(slack.message(), $a.title);
    $m = slack.header($m, $a.title);
    $m = slack.section($m, slack.escape($a.text));
    $m = slack.contextBlock($m, "key `" + slack.escape($a.key) + "`");
    return slack.sendMessage($c.slackUrl, $m);
}

func toDiscord(c as Channels, a as Alert) {
    def m as discord.Message init discord.noMentions(discord.message());
    $m = discord.embed($m, $a.title, $a.text, colour($a.severity));
    $m = discord.embedFooter($m, $a.key);
    return discord.sendMessage($c.discordUrl, $m);
}

# capped limits a server's wait to MAX_WAIT seconds, and at least 0.
func capped(seconds as int) {
    if ($seconds < 0) {
        return 0;
    }
    if ($seconds > MAX_WAIT) {
        return MAX_WAIT;
    }
    return $seconds;
}

# sendOnce posts to one channel and returns the HTTP status; under a
# rate limit it returns 429 and the seconds to wait in the second item.
func sendOnce(c as Channels, a as Alert, ch as string) {
    def r as http.Response;
    match ($ch) {
        when "gotify" { $r = toGotify($c, $a); }
        when "slack" { $r = toSlack($c, $a); }
        when "discord" { $r = toDiscord($c, $a); }
        else {
            try {
                toTelegram($c, $a);
                return [200, 0];
            } catch (e) {
                if ($e.kind != "telegram" or $e.retryAfter == 0) {
                    throw $e;
                }
                return [429, capped($e.retryAfter)];
            }
        }
    }
    def wait as int init 1;
    try {
        $wait = convert.toInt(http.header($r, "Retry-After"));
    } catch (e) {
        $wait = 1;
    }
    return [$r.status, capped($wait)];
}

/**
 * Send to one channel, waiting out up to two rate limits.
 * @param c {Channels} the settings
 * @param a {Alert} the alert
 * @param ch {string} gotify, telegram, slack or discord
 */
export func deliver(c as Channels, a as Alert, ch as string) {
    def status as int init 0;
    for (def attempt in 1..MAX_TRIES + 1) {
        def got as list of int init sendOnce($c, $a, $ch);
        $status = $got[0];
        if ($status >= 200 and $status < 300) {
            return;
        }
        if ($status != 429 or $attempt == MAX_TRIES) {
            break;
        }
        io.printf("%s: 429, retry in %d s\n", $ch, $got[1]);
        time.sleep(time.fromSeconds($got[1]));
    }
    throw AlertError{
        kind: "alert",
        message: "{$ch}: HTTP {$status}",
        channel: $ch,
        status: $status
    };
}

/**
 * The channels that are configured, in a fixed order.
 * @param c {Channels} the settings
 * @return {list of string} channel names
 */
export func enabled(c as Channels) {
    def out as list of string init [];
    if ($c.gotify.url != "") {
        $out[] = "gotify";
    }
    if ($c.chatId != 0) {
        $out[] = "telegram";
    }
    if ($c.slackUrl != "") {
        $out[] = "slack";
    }
    if ($c.discordUrl != "") {
        $out[] = "discord";
    }
    return $out;
}

/**
 * Send an alert everywhere; one failing channel does not stop the rest.
 * @param c {Channels} the settings
 * @param a {Alert} the alert
 * @return {list of string} one line per channel that failed
 */
export func notify(c as Channels, a as Alert) {
    def failed as list of string init [];
    for (def ch in enabled($c)) {
        try {
            deliver($c, $a, $ch);
        } catch (e) {
            $failed[] = "{$ch}: [{$e.kind}] {$e.message}";
        }
    }
    return $failed;
}

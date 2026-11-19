# A dice bot for Telegram, over long polling.
# Run: TELEGRAM_BOT_TOKEN=... jennifer run bot.j
# Against the fake: TELEGRAM_API=http://127.0.0.1:28780 as well.
use convert;
use io;
use json;
use math;
use os;
use regex;
use strings;
use time;
import "@jennifer/telegram/" as telegram;

def const POLL_SECONDS as int init 25;
def const START as string init "Hi! Pick a roll:";
def const HELP as string init "I know /start, /help, /roll 2d6 and /logo.";
# the chat a pressed button belongs to, as a JSON Pointer into the update
def const CHAT_ID as string init "/callback_query/message/chat/id";

# roll("2d6") -> "2d6: 4 + 5 = 9", or a hint for bad input
func roll(spec as string) {
    if (not regex.matches('^[0-9]{1,4}d[0-9]{1,4}$', $spec)) {
        return "Write it like /roll 2d6.";
    }
    def parts as list of string init strings.split($spec, "d");
    def n as int init convert.toInt($parts[0]);
    def sides as int init convert.toInt($parts[1]);
    if ($n < 1 or $n > 20 or $sides < 2 or $sides > 1000) {
        return "1 to 20 dice, 2 to 1000 sides.";
    }
    def dice as list of string init [];
    def sum as int init 0;
    for (def i in 0..$n) {
        def d as int init math.randInt(1, $sides);
        $dice[] = convert.toString($d);
        $sum = $sum + $d;
    }
    return $spec + ": " + strings.join($dice, " + ") + " = " + convert.toString($sum);
}

func keyboard() {
    def rows as list of list of telegram.Button init
        [[telegram.inlineButton("Roll 1d6", "roll:1d6"),
          telegram.inlineButton("Roll 2d6", "roll:2d6")],
         [telegram.urlButton("Jennifer", "https://jennifer-lang.dev/")]];
    return $rows;
}

# reply sends a text, waiting out flood control up to three times
func reply(b as telegram.Bot, chatId as int, text as string) {
    for (def attempt in 0..3) {
        try {
            return telegram.sendMessage($b, $chatId, $text);
        } catch (e) {
            if ($e.kind != "telegram" or $e.retryAfter == 0) { throw $e; }
            io.printf("flood control: wait %d s\n", $e.retryAfter);
            time.sleep(time.fromSeconds($e.retryAfter));
        }
    }
    throw Error{kind: "limit", message: "reply: still flood-limited after 3 tries"};
}

func sendLogo(b as telegram.Bot, chatId as int) {
    telegram.sendChatAction($b, $chatId, "upload_photo");
    telegram.sendPhotoFile($b, $chatId, "jennifer-logo.png", "image/png");
}

func onCommand(b as telegram.Bot, msg as telegram.Message, updateId as int) {
    def words as list of string init regex.split('\s+', strings.trim($msg.text));
    if (not strings.startsWith($words[0], "/")) {
        io.printf("<- %d text\n", $updateId);    # never log what users write
    } else {
        io.printf("<- %d %s\n", $updateId, strings.join($words, " "));
    }
    def arg as string init "1d6";
    if (len($words) > 1) { $arg = $words[1]; }
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
}

func onButton(b as telegram.Bot, raw as json.Value, updateId as int) {
    def q as telegram.CallbackQuery init telegram.parseCallbackQuery($raw);
    io.printf("<- %d button %s\n", $updateId, $q.data);
    telegram.answerCallbackQuery($b, $q.id, "");
    # CallbackQuery has no chat id; read it from the raw update
    def chat as int init json.asInt($raw, CHAT_ID);   # its JSON Pointer
    if (strings.startsWith($q.data, "roll:")) {
        reply($b, $chat, roll($q.data[5..]));
    }
}

func onUpdate(b as telegram.Bot, raw as json.Value) {
    def u as telegram.Update init telegram.parseUpdate($raw);
    if (json.has($raw, "/callback_query")) {
        onButton($b, $raw, $u.updateId);
    } elseif ($u.hasMessage and $u.message.text != "") {
        onCommand($b, $u.message, $u.updateId);
    }
}

# handle runs one update; a failure is logged and skipped
func handle(b as telegram.Bot, raw as json.Value) {
    try {
        onUpdate($b, $raw);
    } catch (e) {
        io.printf("update failed (%s): %s\n", $e.kind,
            telegram.redactToken($e.message, $b.token));
    }
}

def token as string init os.getEnv("TELEGRAM_BOT_TOKEN");
if ($token == "") {
    io.eprintf("bot: set TELEGRAM_BOT_TOKEN\n");
    exit 2;
}
if (os.hasEnv("DICE_SEED")) {
    math.randSeed(convert.toInt(os.getEnv("DICE_SEED")));
}
def b as telegram.Bot init telegram.bot($token);
if (os.getEnv("TELEGRAM_API") != "") {
    $b = telegram.botWith($token, os.getEnv("TELEGRAM_API"));
}
def me as telegram.User init telegram.getMe($b);
io.printf("running as @%s\n", $me.username);

os.catchSignal("term");          # before the loop
os.catchSignal("int");
def offset as int init 0;
def running as bool init true;
while ($running) {
    def updates as list of json.Value init [];
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
    if (os.gotSignal("term") or os.gotSignal("int")) { $running = false; }
}
# confirm the last batch, so a restart does not see it again
try {
    telegram.getUpdatesRaw($b, $offset, 0);   # after it, in a try
} catch (e) {
    io.printf("final poll failed (%s)\n", $e.kind);
}
io.printf("stopped, next offset %d\n", $offset);

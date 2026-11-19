# A fake Telegram Bot API on a loopback port, for running bot.j offline.
# Run: jennifer run fake-telegram.j 28780
# It checks the token in the path (FAKE_TOKEN, default 123456:TEST-TOKEN),
# hands out six scripted updates, three per getUpdates, logs every call
# and answers the fifth sendMessage with a 429 (retry_after 2).
use convert;
use httpd;
use io;
use json;
use maps;
use math;
use os;
use regex;
use strings;
use time;
import "uri.j" as uri;

# an empty poll is held this long at most, not the full timeout
def const HOLD_SECONDS as int init 3;
def const BATCH as int init 3;
def const LIMITED_SEND as int init 5;

def const CHAT as string init '"chat":{"id":42,"type":"private"}';
def const FROM as string init '"from":{"id":42,"is_bot":false,"first_name":"Ada"}';

# a string as a JSON string literal
func quote(s as string) {
    def doc as string init json.encode(json.map({"t": $s}));
    return $doc[5..len($doc) - 1];
}

func message(id as int, text as string) {
    return '{"update_id":' + convert.toString($id) + ',"message":{"message_id":' +
        convert.toString($id + 100) + ',' + FROM + ',' + CHAT +
        ',"date":1763600000,"text":' + quote($text) + '}}';
}

func press(id as int, data as string) {
    return '{"update_id":' + convert.toString($id) +
        ',"callback_query":{"id":"cb' + convert.toString($id) + '",' + FROM +
        ',"message":{"message_id":101,' + CHAT + ',"date":1763600000,"text":"Hi!"}' +
        ',"chat_instance":"1","data":"' + $data + '"}}';
}

# the scripted user: update ids 1 to 6
func script() {
    def out as list of string init [
        message(1, "/start"), press(2, "roll:2d6"), message(3, "/roll 3d20"),
        message(4, "/roll 900d6"), message(5, "/logo"), message(6, "hello")
    ];
    return $out;
}

func ok(req as httpd.Request, result as string) {
    httpd.setHeader($req, "Content-Type", "application/json");
    httpd.respond($req, 200, '{"ok":true,"result":' + $result + '}');
}

func fail(req as httpd.Request, status as int, extra as string) {
    httpd.setHeader($req, "Content-Type", "application/json");
    httpd.respond($req, $status, '{"ok":false,"error_code":' +
        convert.toString($status) + $extra + '}');
}

func sentMessage(chat as string, text as string) {
    return '{"message_id":900,"chat":{"id":' + $chat + ',"type":"private"},' +
        '"date":1763600001,"text":' + quote($text) + '}';
}

func getUpdates(req as httpd.Request, form as map of string to string,
        updates as list of string) {
    def offset as int init convert.toInt($form["offset"]);
    def timeout as int init convert.toInt($form["timeout"]);
    def batch as list of string init [];
    for (def i in 0..len($updates)) {
        if ($i + 1 >= $offset and len($batch) < BATCH) { $batch[] = $updates[$i]; }
    }
    if (len($batch) == 0 and $timeout > 0) {
        time.sleep(time.fromSeconds(math.min($timeout, HOLD_SECONDS)));
    }
    io.printf("tg: getUpdates offset=%d timeout=%d -> %d update(s)\n",
        $offset, $timeout, len($batch));
    ok($req, "[" + strings.join($batch, ",") + "]");
}

def port as string init "28780";
if (len(os.ARGS) > 1) { $port = os.ARGS[1]; }
def token as string init "123456:TEST-TOKEN";
if (os.hasEnv("FAKE_TOKEN")) { $token = os.getEnv("FAKE_TOKEN"); }
def updates as list of string init script();
def sends as int init 0;
def srv as httpd.Server init httpd.listen("127.0.0.1:" + $port);
io.eprintf("fake telegram on %s\n", httpd.address($srv));
while (true) { # lint-disable: L105
    def req as httpd.Request init httpd.accept($srv);
    def m as regex.Match init regex.find('^/bot([^/]*)/([A-Za-z]+)$', httpd.path($req));
    if ($m.start == -1) {
        fail($req, 404, ',"description":"Not Found"');
        continue;
    }
    if ($m.groups[0] != $token) {
        io.printf("tg: %s -> 401, wrong token\n", $m.groups[1]);
        fail($req, 401, ',"description":"Unauthorized"');
        continue;
    }
    def method as string init $m.groups[1];
    def body as bytes init httpd.body($req);
    def form as map of string to string init {};
    if (strings.startsWith(httpd.header($req, "Content-Type"), "application/x-www-form")) {
        $form = uri.parseQuery(convert.stringFromBytes("utf-8", $body));
    }
    match ($method) {
        when "getMe" {
            ok($req, '{"id":7000001,"is_bot":true,"first_name":"Dice",' +
                '"username":"jennifer_dice_bot"}');
        }
        when "getUpdates" { getUpdates($req, $form, $updates); }
        when "sendMessage" {
            $sends = $sends + 1;
            if ($sends == LIMITED_SEND) {
                io.printf("tg: sendMessage -> 429\n");
                fail($req, 429, ',"description":"Too Many Requests: retry after 2"' +
                    ',"parameters":{"retry_after":2}');
                continue;
            }
            def kb as string init "";
            if (maps.has($form, "reply_markup")) { $kb = " +keyboard"; }
            io.printf("tg: sendMessage chat=%s%s \"%s\"\n", $form["chat_id"], $kb,
                $form["text"]);
            ok($req, sentMessage($form["chat_id"], $form["text"]));
        }
        when "answerCallbackQuery" {
            io.printf("tg: answerCallbackQuery %s\n", $form["callback_query_id"]);
            ok($req, "true");
        }
        when "sendChatAction" {
            io.printf("tg: sendChatAction %s\n", $form["action"]);
            ok($req, "true");
        }
        when "sendPhoto" {
            io.printf("tg: sendPhoto multipart, %d bytes\n", len($body));
            ok($req, sentMessage("42", ""));
        }
        else { fail($req, 404, ',"description":"Not Found: method not found"'); }
    }
}

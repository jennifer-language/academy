# A fake of the three LLM APIs on one loopback port, for running the
# programs offline. Run: jennifer run fake.j 28800
# Paths: /v1/messages (Anthropic), /v1/chat/completions (OpenAI, also under
# any prefix, so it stands in for Ollama on 11434 too) and
# /v1beta/models/<id>:generateContent (Gemini). It picks a scripted answer
# from the request: a text reply, a tool-call reply when tools are declared,
# the final answer once tool results came back, and a 429 with retry-after
# 30 for the model "fake-429". It logs which key header arrived, never its
# value.
use convert;
use httpd;
use io;
use os;
use regex;
use strings;

def const TEXT as string init
    "Blue light is scattered most by the air (Rayleigh scattering).";
def const CHILD as string init
    "Sunlight has all colours, and the air bounces the blue around the most.";
def const FINAL as string init
    "Reorder nuts (80) and washers (0); bolts are fine (1200).";
def const ITEMS as list of string init ["bolts", "nuts", "washers"];

# what the request asks for: "text", "child", "tools", "final" or "429"
func pick(body as string, model as string) {
    if ($model == "fake-429") { return "429"; }
    if (strings.contains($body, "tool_result") or
        strings.contains($body, '"role":"tool"') or
        strings.contains($body, "functionResponse")) {
        return "final";
    }
    if (strings.contains($body, '"tools"')) { return "tools"; }
    if (strings.contains($body, "five-year-old")) { return "child"; }
    return "text";
}

func say(what as string) {
    if ($what == "child") { return CHILD; }
    if ($what == "final") { return FINAL; }
    return TEXT;
}

func anthropic(what as string) {
    if ($what == "429") {
        return '{"type":"error","error":{"type":"rate_limit_error",' +
            '"message":"Number of request tokens has exceeded your rate limit."}}';
    }
    def content as string init '[{"type":"text","text":"' + say($what) + '"}]';
    def stop as string init "end_turn";
    if ($what == "tools") {
        def calls as list of string init [];
        for (def i in 0..len(ITEMS)) {
            $calls[] = '{"type":"tool_use","id":"toolu_0' + convert.toString($i + 1) +
                '","name":"stock_level","input":{"item":"' + ITEMS[$i] + '"}}';
        }
        $content = "[" + strings.join($calls, ",") + "]";
        $stop = "tool_use";
    }
    return '{"id":"msg_01","type":"message","role":"assistant",' +
        '"model":"claude-opus-5-5","content":' + $content +
        ',"stop_reason":"' + $stop + '","stop_sequence":null,' +
        '"usage":{"input_tokens":21,"output_tokens":17}}';
}

func openai(what as string, model as string) {
    if ($what == "429") {
        return '{"error":{"message":"Rate limit reached for requests",' +
            '"type":"requests","param":null,"code":"rate_limit_exceeded"}}';
    }
    def message as string init '{"role":"assistant","content":"' + say($what) +
        '","refusal":null}';
    def finish as string init "stop";
    if ($what == "tools") {
        def calls as list of string init [];
        for (def i in 0..len(ITEMS)) {
            $calls[] = '{"id":"call_' + convert.toString($i + 1) +
                '","type":"function","function":{"name":"stock_level",' +
                '"arguments":"{\"item\":\"' + ITEMS[$i] + '\"}"}}';
        }
        $message = '{"role":"assistant","content":null,"tool_calls":[' +
            strings.join($calls, ",") + ']}';
        $finish = "tool_calls";
    }
    return '{"id":"chatcmpl-1","object":"chat.completion","created":1763600000,' +
        '"model":"' + $model + '","choices":[{"index":0,"message":' + $message +
        ',"finish_reason":"' + $finish + '"}],' +
        '"usage":{"prompt_tokens":24,"completion_tokens":15,"total_tokens":39}}';
}

func gemini(what as string, model as string) {
    if ($what == "429") {
        return '{"error":{"code":429,"message":"Resource has been exhausted.",' +
            '"status":"RESOURCE_EXHAUSTED","details":[{"@type":' +
            '"type.googleapis.com/google.rpc.RetryInfo","retryDelay":"30s"}]}}';
    }
    def parts as string init '[{"text":"' + say($what) + '"}]';
    if ($what == "tools") {
        def calls as list of string init [];
        for (def item in ITEMS) {
            $calls[] = '{"functionCall":{"name":"stock_level","args":{"item":"' +
                $item + '"}}}';
        }
        $parts = "[" + strings.join($calls, ",") + "]";
    }
    return '{"candidates":[{"content":{"role":"model","parts":' + $parts +
        '},"finishReason":"STOP","index":0}],"usageMetadata":{' +
        '"promptTokenCount":9,"candidatesTokenCount":14,"totalTokenCount":23},' +
        '"modelVersion":"' + $model + '","responseId":"fake-1"}';
}

func keyHeader(req as httpd.Request) {
    for (def h in ["x-api-key", "Authorization", "x-goog-api-key", "api-key"]) {
        if (httpd.header($req, $h) != "") { return $h; }
    }
    return "no key";
}

def port as string init "28800";
if (len(os.ARGS) > 1) { $port = os.ARGS[1]; }
def srv as httpd.Server init httpd.listen("127.0.0.1:" + $port);
io.eprintf("fake LLM APIs on %s\n", httpd.address($srv));
while (true) { # lint-disable: L105
    def req as httpd.Request init httpd.accept($srv);
    def path as string init httpd.path($req);
    def raw as bytes init httpd.body($req);
    def body as string init convert.stringFromBytes("utf-8", $raw);
    def answer as string init "";
    def what as string init "";
    if ($path == "/v1/messages") {
        def m as regex.Match init regex.find('"model":"([^"]*)"', $body);
        $what = pick($body, $m.groups[0]);
        $answer = anthropic($what);
    } elseif (strings.endsWith($path, "/chat/completions")) {
        def m as regex.Match init regex.find('"model":"([^"]*)"', $body);
        $what = pick($body, $m.groups[0]);
        $answer = openai($what, $m.groups[0]);
    } elseif (regex.matches('^/v1beta/models/[^/]+:generateContent$', $path)) {
        def model as string init regex.find('models/([^:]+):', $path).groups[0];
        $what = pick($body, $model);
        $answer = gemini($what, $model);
    } else {
        io.printf("fake: %s %s -> 404\n", httpd.method($req), $path);
        httpd.respond($req, 404, "not found\n");
        continue;
    }
    httpd.setHeader($req, "Content-Type", "application/json");
    if ($what == "429") {
        io.printf("fake: %s %s (%s) -> 429, retry-after 30\n", httpd.method($req),
            $path, keyHeader($req));
        httpd.setHeader($req, "retry-after", "30");
        httpd.respond($req, 429, $answer);
        continue;
    }
    io.printf("fake: %s %s (%s) -> 200, %d bytes in\n", httpd.method($req), $path,
        keyHeader($req), len($raw));
    httpd.respond($req, 200, $answer);
}

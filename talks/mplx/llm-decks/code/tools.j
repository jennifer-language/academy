# "Tools: declare them", "Tools: the loop" and "Tools: what happened".
# Run: jennifer run tools.j [anthropic|openai|gemini]
# with the vendor's key (and base URL) set.
use convert; use io; use json; use os;
import "@deckyard/anthropic/" as anthropic;
import "@deckyard/openai/" as openai;
import "@deckyard/gemini/" as gemini;

def const QUESTION as string init "Which of bolts, nuts and washers need " +
    "reordering? Below 100 means reorder.";

# the tool handler; stock is the context runToolsWith passes through
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

# the same handler for the other two decks, with their toolError
func levelOpenai(name as string, input as json.Value, stock as json.Value) {
    if ($name != "stock_level") { return openai.toolError("no tool " + $name); }
    def item as string init json.asString($input, "/item");
    if (json.typeOf($stock, "/" + $item) != "int") {
        return openai.toolError("unknown item " + $item);
    }
    def n as int init json.asInt($stock, "/" + $item);
    return json.decode('{"count":' + convert.toString($n) + '}');
}

func levelGemini(name as string, input as json.Value, stock as json.Value) {
    if ($name != "stock_level") { return gemini.toolError("no tool " + $name); }
    def item as string init json.asString($input, "/item");
    if (json.typeOf($stock, "/" + $item) != "int") {
        return gemini.toolError("unknown item " + $item);
    }
    def n as int init json.asInt($stock, "/" + $item);
    return json.decode('{"count":' + convert.toString($n) + '}');
}

def vendor as string init "anthropic";
if (len(os.ARGS) > 1) { $vendor = os.ARGS[1]; }
def stock as json.Value init json.decode('{"bolts": 1200, "nuts": 80, "washers": 0}');
def schema as json.Value init json.decode(
    '{"type":"object","required":["item"],' +
    '"properties":{"item":{"type":"string"}},' +
    '"additionalProperties":false}');
def desc as string init "How many of an item are in stock.";
def answer as string init "";
def calls as int init 0;
def turns as int init 0;
def stopped as string init "";
if ($vendor == "anthropic") {
    def c as anthropic.Client init anthropic.client(os.getEnv("ANTHROPIC_API_KEY"));
    if (os.hasEnv("ANTHROPIC_BASE_URL")) {
        $c = anthropic.withBaseUrl($c, os.getEnv("ANTHROPIC_BASE_URL"));
    }
    def req as json.Value init anthropic.newRequest("claude-opus-5-5");
    $req = anthropic.addUserText($req, QUESTION);
    def t as json.Value init anthropic.tool(
        "stock_level", "How many of an item are in stock.", $schema);
    $req = anthropic.addTool($req, anthropic.withStrict($t));
    def run as anthropic.ToolRun init anthropic.runToolsWith($c, $req, level, $stock, 10);
    $answer = anthropic.text($run.reply);
    $calls = $run.calls; $turns = $run.turns; $stopped = $run.stopped;
} elseif ($vendor == "openai") {
    def c as openai.Client init openai.client(os.getEnv("OPENAI_API_KEY"));
    if (os.hasEnv("OPENAI_BASE_URL")) {
        $c = openai.withBaseUrl($c, os.getEnv("OPENAI_BASE_URL"));
    }
    def req as json.Value init openai.newRequest("gpt-5.4-mini");
    $req = openai.addUserText($req, QUESTION);
    $req = openai.addTool($req,
        openai.withStrict(openai.tool("stock_level", $desc, $schema)));
    def run as openai.ToolRun init openai.runToolsWith($c, $req, levelOpenai, $stock, 10);
    $answer = openai.text($run.reply);
    $calls = $run.calls; $turns = $run.turns; $stopped = $run.stopped;
} else {
    def c as gemini.Client init gemini.client(os.getEnv("GEMINI_API_KEY"));
    if (os.hasEnv("GEMINI_BASE_URL")) {
        $c = gemini.withBaseUrl($c, os.getEnv("GEMINI_BASE_URL"));
    }
    def req as json.Value init gemini.newRequest("gemini-3.8-flash");
    $req = gemini.addUserText($req, QUESTION);
    # no strict mode in Gemini: the handler checks the input
    $req = gemini.addTool($req, gemini.tool("stock_level", $desc, $schema));
    def run as gemini.ToolRun init gemini.runToolsWith($c, $req, levelGemini, $stock, 10);
    $answer = gemini.text($run.reply);
    $calls = $run.calls; $turns = $run.turns; $stopped = $run.stopped;
}
io.printf("%s\n", $answer);
io.printf("[%d tool calls in %d requests, stopped \"%s\"]\n", $calls, $turns, $stopped);

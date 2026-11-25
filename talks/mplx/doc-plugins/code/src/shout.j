# pragma-jennifer-version: >=0.27.0
# pragma-jennifer-capability: exec

/**
 * A complete preprocessor for Grimoire and Cantrip, small enough to read in
 * one sitting: every `shout` fence is handed to an external program (`awk` by
 * default), and its output replaces the fence as a `text` fence.
 *
 * It speaks the plugin contract, api 1, without Grimoire's plugin kit, so each
 * step is visible: read the request, check it, read the settings, find the
 * fences, run the program with caps and a timeout, reply with the chapters it
 * changed.
 * @module shout
 */
use io;
use os;
use fs;
use path;
use json;
use strings;
use convert;
use regex;
use time;
use encoding;

def const API as int init 1;
def const NAME as string init "grimoire-shout";

# The fence language this plugin rewrites.
def const LANGUAGE as string init "shout";

# Caps: one fence's text, the program's output for it, and fences per chapter.
def const MAX_SOURCE as int init 65536;
def const MAX_OUTPUT as int init 1048576;
def const MAX_FENCES as int init 200;

# The timeout a book may set, in milliseconds, and the default.
def const DEFAULT_TIMEOUT as int init 10000;
def const MAX_TIMEOUT as int init 60000;

# The settings this plugin reads, and the keys the host itself uses.
def const SETTINGS as list of string init ["program", "timeout"];
def const HOST_KEYS as list of string init ["command", "args"];

# --- errors ------------------------------------------------------------

func fail(message as string) {
    throw Error{kind: "plugin", message: $message};
}

func failAt(kind as string, chapter as string, line as int, message as string) {
    throw Error{kind: $kind, message: "{$chapter}:{$line}: {$message}"};
}

# --- the request -------------------------------------------------------

/**
 * Decode a request and check that this plugin can answer it.
 * @param text {string} what arrived on stdin
 * @return {json.Value} the request
 * @throws {Error} kind "plugin" for an empty request, another api or kind
 */
export func request(text as string) {
    if (strings.trim($text) == "") {
        fail("no request on stdin; grimoire or cantrip runs this program");
    }
    def req as json.Value init json.decode($text);
    if (json.typeOf($req, "/api") != "int" or json.asInt($req, "/api") != API) {
        fail("this plugin speaks api 1 only");
    }
    if (json.typeOf($req, "/kind") != "string" or json.asString($req, "/kind") != "preprocessor") {
        fail("this is a preprocessor");
    }
    return $req;
}

/**
 * What the plugin's table says, checked.
 * @field program {string} the program each fence is handed to
 * @field timeout {int} milliseconds one run may take
 */
export def struct Settings {
    program as string,
    timeout as int
};

/**
 * Read the settings: an unknown key or a value of the wrong type is an error,
 * never ignored.
 * @param req {json.Value} the request
 * @return {Settings} the settings, defaults filled in
 * @throws {Error} kind "plugin" for a bad setting
 */
export func settingsOf(req as json.Value) {
    def out as Settings init Settings{program: "awk", timeout: DEFAULT_TIMEOUT};
    def at as string init "/plugin/settings";
    if (json.typeOf($req, $at) != "map") {
        return $out;
    }
    for (def key in json.keys($req, $at)) {
        if (not (inList(SETTINGS, $key) or inList(HOST_KEYS, $key))) {
            fail("unknown setting `{$key}`; the settings are program, timeout");
        }
    }
    if (json.has($req, $at + "/program")) {
        if (json.typeOf($req, $at + "/program") != "string") {
            fail("setting `program` must be a string");
        }
        $out.program = json.asString($req, $at + "/program");
    }
    if (json.has($req, $at + "/timeout")) {
        if (json.typeOf($req, $at + "/timeout") != "int") {
            fail("setting `timeout` must be a whole number of milliseconds");
        }
        $out.timeout = json.asInt($req, $at + "/timeout");
    }
    if ($out.program == "") {
        fail("setting `program` is empty");
    }
    if ($out.timeout < 1 or $out.timeout > MAX_TIMEOUT) {
        fail("setting `timeout` must be 1 to {MAX_TIMEOUT} milliseconds");
    }
    return $out;
}

func inList(items as list of string, item as string) {
    for (def x in $items) {
        if ($x == $item) {
            return true;
        }
    }
    return false;
}

# --- fences ------------------------------------------------------------

/**
 * One `shout` fence.
 * @field first {int} the index of the opening line
 * @field last {int} the index of the closing line
 * @field indent {string} the opener's indentation
 * @field body {string} the text between, indentation removed
 */
export def struct Fence {
    first as int,
    last as int,
    indent as string,
    body as string
};

/**
 * Every `shout` fence in a chapter. Fences of other languages are skipped as
 * a whole, so a page can show the syntax inside a longer fence.
 * @param chapter {string} the chapter's `src`, for errors
 * @param content {string} the chapter's Markdown
 * @return {list of Fence} the fences, in order
 * @throws {Error} kind "plugin" for an unclosed `shout` fence; "limit" over a cap
 */
export func fencesIn(chapter as string, content as string) {
    def out as list of Fence;
    def lines as list of string init strings.split($content, "\n");
    def i as int init 0;
    while ($i < len($lines)) {
        def open as regex.Match init regex.find('^( {0,3})(`{3,}|~{3,})\s*([^`\s]*)', $lines[$i]);
        if ($open.start < 0) {
            $i = $i + 1;
            continue;
        }
        def mark as string init $open.groups[1];
        def close as string init '^ {0,3}' + regex.escape($mark) + regex.escape($mark[..1]) +
            '*\s*$';
        def j as int init $i + 1;
        while ($j < len($lines) and not regex.matches($close, $lines[$j])) {
            $j = $j + 1;
        }
        if ($open.groups[2] == LANGUAGE) {
            if ($j == len($lines)) {
                failAt("plugin", $chapter, $i + 1, "the shout fence is never closed");
            }
            if (len($out) == MAX_FENCES) {
                failAt("limit", $chapter, $i + 1, "more than {MAX_FENCES} shout fences");
            }
            def body as list of string;
            for (def line in $lines[$i + 1..$j]) {
                $body[] = strings.trimPrefix($line, $open.groups[0]);
            }
            def text as string init strings.join($body, "\n");
            if (encoding.lenBytes($text) > MAX_SOURCE) {
                failAt("limit", $chapter, $i + 1, "the fence is over {MAX_SOURCE} bytes");
            }
            $out[] = Fence{first: $i, last: $j, indent: $open.groups[0], body: $text};
        }
        $i = $j + 1;
    }
    return $out;
}

# --- running the program -----------------------------------------------

/**
 * Run a program, and stop it when it takes longer than `ms` milliseconds.
 * `os.spawn` takes no stdin, so the input travels as a file named in `argv`.
 * @param argv {list of string} the program and its arguments
 * @param ms {int} the timeout
 * @return {os.Result} what it printed, and its exit status
 * @throws {Error} kind "timeout" when it ran too long; "plugin" when it cannot start
 */
export func runBounded(argv as list of string, ms as int) {
    def p as os.Process;
    try {
        $p = os.spawn($argv);
    } catch (e) {
        fail("cannot run {$argv[0]} ({$e.message}); install it, or set `program`");
    }
    def started as time.Time init time.now();
    while (not os.poll($p)) {
        if (time.milliseconds(time.sub(time.now(), $started)) >= $ms) {
            os.kill($p);
            os.wait($p);
            os.release($p);
            throw Error{kind: "timeout", message: "{$argv[0]} did not finish within {$ms} ms"};
        }
        time.sleep(time.fromMilliseconds(10));
    }
    def r as os.Result init os.wait($p);
    os.release($p);
    return $r;
}

# The first line of a message that has text on it.
func firstLine(text as string) {
    for (def line in strings.split($text, "\n")) {
        if (strings.trim($line) != "") {
            return strings.trim($line);
        }
    }
    return "";
}

/**
 * Hand one fence to the program and return what it printed.
 * @param s {Settings} the settings
 * @param dir {string} a private directory for the input file
 * @param chapter {string} the chapter, for errors
 * @param f {Fence} the fence
 * @return {string} the program's output
 */
func shout(s as Settings, dir as string, chapter as string, f as Fence) {
    def input as string init path.join($dir, "fence.txt");
    fs.writeString($input, $f.body + "\n");
    def r as os.Result;
    try {
        $r = runBounded([$s.program, '{ print toupper($0) }', $input], $s.timeout);
    } catch (e) {
        failAt($e.kind, $chapter, $f.first + 1, $e.message);
    }
    if ($r.exitCode != 0) {
        failAt("plugin", $chapter, $f.first + 1, $s.program + ": " + firstLine($r.stderr));
    }
    if (encoding.lenBytes($r.stdout) > MAX_OUTPUT) {
        failAt("limit", $chapter, $f.first + 1, "the output is over {MAX_OUTPUT} bytes");
    }
    return strings.trimSuffix($r.stdout, "\n");
}

# --- the reply ---------------------------------------------------------

# A fence one backtick longer than any run of backticks in the text, so the
# program's output cannot close it early.
func fenceFor(text as string) {
    def longest as int init 2;
    for (def m in regex.findAll('`+', $text)) {
        if (len($m.text) > $longest) {
            $longest = len($m.text);
        }
    }
    return strings.replicate("`", $longest + 1);
}

/**
 * A chapter with each fence replaced by the program's output.
 * @param content {string} the chapter
 * @param fences {list of Fence} its `shout` fences
 * @param outputs {list of string} the output for each, in the same order
 * @return {string} the new chapter
 */
export func rewrite(content as string, fences as list of Fence, outputs as list of string) {
    def lines as list of string init strings.split($content, "\n");
    def out as list of string;
    def i as int init 0;
    def k as int init 0;
    while ($i < len($lines)) {
        if ($k < len($fences) and $fences[$k].first == $i) {
            def f as Fence init $fences[$k];
            def mark as string init fenceFor($outputs[$k]);
            $out[] = $f.indent + $mark + "text";
            for (def line in strings.split($outputs[$k], "\n")) {
                $out[] = $f.indent + $line;
            }
            $out[] = $f.indent + $mark;
            $i = $f.last + 1;
            $k = $k + 1;
            continue;
        }
        $out[] = $lines[$i];
        $i = $i + 1;
    }
    return strings.join($out, "\n");
}

/**
 * Answer one request: the reply lists only the chapters that changed.
 * @param req {json.Value} the checked request
 * @return {string} the reply, as JSON
 */
export func replyFor(req as json.Value) {
    def s as Settings init settingsOf($req);
    def dir as string init fs.makeTempDir(os.tempDir(), "grimoire-shout-");
    defer fs.removeAll($dir);
    def changed as list of string;
    for (def i in 0..json.length($req, "/chapters")) {
        def at as string init "/chapters/" + convert.toString($i);
        def src as string init json.asString($req, $at + "/src");
        def content as string init json.asString($req, $at + "/content");
        def fences as list of Fence init fencesIn($src, $content);
        if (len($fences) == 0) {
            continue;
        }
        def outputs as list of string;
        for (def f in $fences) {
            $outputs[] = shout($s, $dir, $src, $f);
        }
        $changed[] = '{"src":' + json.encode($src) + ',"content":' +
            json.encode(rewrite($content, $fences, $outputs)) + '}';
    }
    return '{"api":1,"chapters":[' + strings.join($changed, ",") + ']}';
}

/**
 * Run the plugin over one request: the reply on stdout, or the reason on
 * stderr and status 1, which stops the build.
 * @param text {string} the request from stdin
 * @return {int} the exit status
 */
export func run(text as string) {
    try {
        io.printf("%s", replyFor(request($text)));
        return 0;
    } catch (e) {
        io.eprintf("%s: %s\n", NAME, $e.message);
        return 1;
    }
}

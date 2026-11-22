# docs.inc.j: the jennifer-docs server's tools, resources and prompt,
# shared by docs.j (stdio) and docshttp.j (Streamable HTTP).
import "mcp.j" as mcp;
use io;
use os;
use fs;
use json;
use lists;
use regex;
use strings;

def const MAX_HITS as int init 8;
def const EXCERPT as int init 72;

def struct Hit {
    page as string,
    count as int,
    heading as string,
    line as string
};

if (len(os.ARGS) != 2 or not fs.isDir(os.ARGS[1])) {
    io.eprintf("usage: jennifer run docs.j DOCS_DIR\n");
    exit 2;
}
def root as string init fs.realpath(os.ARGS[1]);

# docPages lists every *.md below the root, relative and sorted.
# fs.walk does not follow symlinks below the root.
func docPages() {
    def found as list of string init [];
    for (def st in fs.walk($root)) {
        if (not $st.isDir and strings.endsWith($st.path, ".md")) {
            $found[] = $st.path[len($root) + 1..];
        }
    }
    return lists.sort($found);
}

def pages as list of string init docPages();

# requireString reads a string argument with a length cap, or throws.
func requireString(args as json.Value, key as string, max as int) {
    if (json.typeOf($args, "/" + $key) != "string") {
        throw Error{kind: "value", message: $key + " must be a string"};
    }
    def v as string init strings.trim(json.asString($args, "/" + $key));
    if (len($v) < 2 or len($v) > $max) {
        throw Error{kind: "value", message: $key + ": bad length"};
    }
    return $v;
}

# clip shortens one line of text for an excerpt.
func clip(s as string) {
    def t as string init strings.trim($s);
    if (len($t) <= EXCERPT) {
        return $t;
    }
    return $t[..EXCERPT] + "...";
}

# firstHit finds where a page first mentions q: the heading above
# that line (not a comment in a code block) and the line itself.
func firstHit(page as string, text as string, q as string, n as int) {
    def heading as string init "";
    def code as bool init false;
    for (def l in strings.split($text, "\n")) {
        if (strings.startsWith($l, "```")) {
            $code = not $code;
        }
        if (not $code and strings.startsWith($l, "#")) {
            $heading = strings.trim($l);
        }
        if (strings.contains(strings.lower($l), $q)) {
            return Hit{page: $page, count: $n, heading: $heading, line: clip($l)};
        }
    }
    return Hit{page: $page, count: $n, heading: "", line: ""};
}

func hitKey(h as Hit) {
    return -$h.count;
}

# The tool search_docs: the pages that mention a word or phrase, most
# mentions first, each with its section heading and one line.
func searchDocs(args as json.Value) {
    def q as string init strings.lower(requireString($args, "query", 100));
    def hits as list of Hit init [];
    for (def p in $pages) {
        def text as string init fs.readString($root + "/" + $p);
        def n as int init strings.count(strings.lower($text), $q);
        if ($n > 0) {
            $hits[] = firstHit($p, $text, $q, $n);
        }
    }
    if (len($hits) == 0) {
        return "No page mentions \"" + $q + "\".";
    }
    $hits = lists.sortBy($hits, hitKey);
    def out as list of string init [];
    def shown as int init 0;
    for (def h in $hits) {
        if ($shown == MAX_HITS) {
            break;
        }
        $out[] = "docs://" + $h.page + " ({$h.count}x) " + $h.heading;
        $out[] = "    " + $h.line;
        $shown = $shown + 1;
    }
    def total as int init len($hits);
    $out[] = "matching pages: {$total}; read one with read_doc.";
    return strings.join($out, "\n");
}

# The tool read_doc: one page, by its path relative to the root. Only
# a path from the list docPages made is read; nothing else is opened.
func readDoc(args as json.Value) {
    def p as string init strings.replace(requireString($args, "path", 200), "docs://", "");
    if (not lists.contains($pages, $p)) {
        return "No such page: " + $p + ". Use search_docs to find one.";
    }
    return fs.readString($root + "/" + $p);
}

# A resource: one page. Only registered URIs reach this handler.
func readResource(uri as json.Value) {
    def p as string init json.asString($uri, "")[7..];
    return fs.readString($root + "/" + $p);
}

# The prompt explain_function: a ready-made request for the model.
func explainFunction(args as json.Value) {
    def name as string init requireString($args, "name", 60);
    if (not regex.matches("^[a-z][a-zA-Z0-9]*\\.[a-zA-Z][a-zA-Z0-9]*$", $name)) {
        throw Error{kind: "value", message: "name: lib.function"};
    }
    def text as string init "Explain the Jennifer function " + $name + ". Use the " +
        "search_docs and read_doc tools; give its signature, what it " +
        "returns, what it throws and a short example, and name the page.";
    def msg as json.Value init json.decode('{"role":"user","content":{"type":"text","text":""}}');
    $msg = json.set($msg, "/content/text", $text);
    return json.append(json.list(), "", $msg);
}

func docsServer() {
    def s as mcp.Server init mcp.server("jennifer-docs", "0.1.0");
    def q as json.Value init mcp.property(
        mcp.schema(),
        "query",
        "string",
        "a word or phrase, 2 to 100 characters, such as json.decode",
        true);
    $s = mcp.addTool(
        $s,
        "search_docs",
        "Search the Jennifer language documentation. Use it before " +
            "answering a question about a Jennifer library, module or " +
            "function. Returns page paths with a matching line.",
        $q,
        searchDocs);
    def r as json.Value init mcp.property(
        mcp.schema(),
        "path",
        "string",
        "a page path from search_docs, such as libraries/json.md",
        true);
    $s = mcp.addTool(
        $s,
        "read_doc",
        "Read one page of the Jennifer documentation as Markdown.",
        $r,
        readDoc);
    for (def p in $pages) {
        $s = mcp.addResource(
            $s,
            "docs://" + $p,
            $p,
            "Jennifer docs: " + $p,
            "text/markdown",
            readResource);
    }
    def a as mcp.PromptArg init mcp.promptArg("name", "a function, such as json.decode", true);
    $s = mcp.addPrompt(
        $s,
        "explain_function",
        "Explain one Jennifer function from the documentation.",
        [$a],
        explainFunction);
    return $s;
}

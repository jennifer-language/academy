# client.j: test docs.j with the mcp module's own stdio client
import "mcp.j" as mcp;
use io;
use os;
use json;
use strings;

def c as mcp.Client init mcp.connectStdio(["jennifer", "run", "docs.j", os.ARGS[1]]);
def info as json.Value init mcp.initialize($c);
io.printf(
    "protocol %s, server %s\n",
    json.asString($info, "/protocolVersion"),
    json.asString($info, "/serverInfo/name"));
def tools as json.Value init mcp.listTools($c);
io.printf("tools: %s, %s\n", json.asString($tools, "/0/name"), json.asString($tools, "/1/name"));

def a as json.Value init json.set(json.map(), "/query", "realpath");
def out as json.Value init mcp.callTool($c, "search_docs", $a);
io.printf("%s\n", json.asString($out, "/content/0/text"));

def p as json.Value init json.set(json.map(), "/path", "libraries/path.md");
$out = mcp.callTool($c, "read_doc", $p);
def text as string init json.asString($out, "/content/0/text");
io.printf("read_doc: %d characters, first line %s\n", len($text), strings.split($text, "\n")[0]);

def bad as json.Value init json.set(json.map(), "/path", "../../../etc/passwd");
$out = mcp.callTool($c, "read_doc", $bad);
io.printf(
    "traversal: isError %t, %s\n",
    json.asBool($out, "/isError"),
    json.asString($out, "/content/0/text"));

def rs as json.Value init mcp.listResources($c);
io.printf("resources: %d, first %s\n", json.length($rs, ""), json.asString($rs, "/0/uri"));
def r as json.Value init mcp.readResource($c, "docs://libraries/json.md");
io.printf("resources/read: %s\n", json.asString($r, "/contents/0/mimeType"));
try {
    mcp.readResource($c, "docs://../../etc/passwd");
} catch (e) {
    io.printf("resources/read traversal: %s\n", $e.message);
}
def g as json.Value init mcp.getPrompt(
    $c,
    "explain_function",
    json.set(json.map(), "/name", "path.clean"));
io.printf("prompt: %s\n", json.asString($g, "/messages/0/content/text"));

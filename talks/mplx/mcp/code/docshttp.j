# docshttp.j: the jennifer-docs server over Streamable HTTP, JSON
# replies only, behind a bearer token. Usage:
# DOCS_TOKEN=... jennifer run docshttp.j /path/to/jennifer/docs
include "docs.inc.j";
import "web.j" as web;
use hash;
use convert;

def const ADDR as string init "127.0.0.1:8931";
def const ORIGIN as string init "http://127.0.0.1:8931";

def token as string init os.getEnv("DOCS_TOKEN");
if (len($token) < 32) {
    io.eprintf("jennifer-docs: set DOCS_TOKEN, at least 32 characters\n");
    exit 2;
}
def srv as mcp.Server init docsServer();

func utf8(s as string) {
    return convert.bytesFromString("utf-8", $s);
}

func postMcp(ctx as web.Context) {
    def origin as string init web.header($ctx, "Origin");
    if ($origin != "" and $origin != ORIGIN) {
        web.text($ctx, 403, "origin not allowed\n");
        return;
    }
    if (not hash.equal(utf8(web.bearerToken($ctx)), utf8($token))) {
        web.setHeader($ctx, "WWW-Authenticate", "Bearer");
        web.text($ctx, 401, "bearer token required\n");
        return;
    }
    def body as string;
    try {
        $body = convert.stringFromBytes("utf-8", web.body($ctx));
    } catch (e) {
        web.text($ctx, 400, "body is not UTF-8\n");
        return;
    }
    def reply as string init mcp.handle($srv, $body);
    if ($reply == "") {
        web.respond($ctx, 202, "");
        return;
    }
    web.setHeader($ctx, "Content-Type", "application/json");
    web.respond($ctx, 200, $reply);
}

func getMcp(ctx as web.Context) {
    web.setHeader($ctx, "Allow", "POST");
    web.text($ctx, 405, "no server-sent event stream here\n");
}

def app as web.App init web.new();
$app = web.post($app, "/mcp", postMcp);
$app = web.get($app, "/mcp", getMcp);
io.eprintf("jennifer-docs: MCP on http://%s/mcp\n", ADDR);
web.run($app, ADDR);

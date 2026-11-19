# httpclient.j: call docshttp.j with the mcp module's HTTP client
import "mcp.j" as mcp;
use io;
use os;
use json;

def auth as string init "Bearer " + os.getEnv("DOCS_TOKEN");
def c as mcp.Client init mcp.connectWith("http://127.0.0.1:8931/mcp", {"Authorization": $auth});
def info as json.Value init mcp.initialize($c);
io.printf("protocol %s\n", json.asString($info, "/protocolVersion"));
def args as json.Value init json.set(json.map(), "/query", "bearerToken");
def out as json.Value init mcp.callTool($c, "search_docs", $args);
io.printf("%s\n", json.asString($out, "/content/0/text"));

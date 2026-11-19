# "A first message: Claude", with the base URL override from "Testing
# without a key". Run: ANTHROPIC_API_KEY=... jennifer run claude.j
use io; use json; use os;
import "@deckyard/anthropic/" as anthropic;

def key as string init os.getEnv("ANTHROPIC_API_KEY");
def c as anthropic.Client init anthropic.client($key);
if (os.hasEnv("ANTHROPIC_BASE_URL")) {
    $c = anthropic.withBaseUrl($c, os.getEnv("ANTHROPIC_BASE_URL"));
}
def req as json.Value init anthropic.newRequest("claude-opus-5-5");
$req = anthropic.withSystem($req, "Answer in one sentence.");
$req = anthropic.addUserText($req, "Why is the sky blue?");
def reply as json.Value init anthropic.chat($c, $req);
io.printf("%s\n", anthropic.text($reply));

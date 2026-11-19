# "Errors: match the kind, then read fields": a 429 from each vendor, with
# the decks' retries switched off. Against fake.j the model "fake-429" is
# answered with a 429 and retry-after 30.
# Run: jennifer run errors.j (keys and base URLs set; see README.md)
use io; use json; use os;
import "@deckyard/anthropic/" as anthropic;
import "@deckyard/openai/" as openai;
import "@deckyard/gemini/" as gemini;

def const MODEL as string init "fake-429";

def c as anthropic.Client init anthropic.client(os.getEnv("ANTHROPIC_API_KEY"));
if (os.hasEnv("ANTHROPIC_BASE_URL")) {
    $c = anthropic.withBaseUrl($c, os.getEnv("ANTHROPIC_BASE_URL"));
}
$c = anthropic.withRetries($c, 0);
def req as json.Value init anthropic.addUserText(anthropic.newRequest(MODEL), "Hi");
def reply as json.Value;
try {
    $reply = anthropic.chat($c, $req);
} catch (e) {
    if ($e.kind != "anthropic") {
        throw $e;
    }
    def err as anthropic.AnthropicError init $e;
    io.printf("HTTP %d %s, wait %d ms\n",
        $err.status, $err.type, $err.retryAfterMs);
}

def oc as openai.Client init openai.client(os.getEnv("OPENAI_API_KEY"));
if (os.hasEnv("OPENAI_BASE_URL")) {
    $oc = openai.withBaseUrl($oc, os.getEnv("OPENAI_BASE_URL"));
}
$oc = openai.withRetries($oc, 0);
try {
    openai.chat($oc, openai.addUserText(openai.newRequest(MODEL), "Hi"));
} catch (e) {
    if ($e.kind != "openai") {
        throw $e;
    }
    def err as openai.OpenaiError init $e;
    io.printf("HTTP %d %s, wait %d ms\n", $err.status, $err.code, $err.retryAfterMs);
}

def gc as gemini.Client init gemini.client(os.getEnv("GEMINI_API_KEY"));
if (os.hasEnv("GEMINI_BASE_URL")) {
    $gc = gemini.withBaseUrl($gc, os.getEnv("GEMINI_BASE_URL"));
}
$gc = gemini.withRetries($gc, 0);
try {
    gemini.chat($gc, gemini.addUserText(gemini.newRequest(MODEL), "Hi"));
} catch (e) {
    if ($e.kind != "gemini") {
        throw $e;
    }
    def err as gemini.GeminiError init $e;
    io.printf("HTTP %d %s, wait %d ms\n", $err.status, $err.googleStatus,
        $err.retryAfterMs);
}

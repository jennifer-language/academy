# "The same in GPT and Gemini": the Gemini half.
# Run: GEMINI_API_KEY=... jennifer run gemini.j
use io; use json; use os;
import "@deckyard/gemini/" as gemini;

def key as string init os.getEnv("GEMINI_API_KEY");
def c as gemini.Client init gemini.client($key);   # GEMINI_API_KEY
if (os.hasEnv("GEMINI_BASE_URL")) {
    $c = gemini.withBaseUrl($c, os.getEnv("GEMINI_BASE_URL"));
}
def req as json.Value init gemini.newRequest("gemini-3.8-flash");
$req = gemini.withSystem($req, "Answer in one sentence.");
$req = gemini.addUserText($req, "Why is the sky blue?");
io.printf("%s\n", gemini.text(gemini.chat($c, $req)));

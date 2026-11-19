# "The same in GPT and Gemini": the GPT half.
# Run: OPENAI_API_KEY=... jennifer run gpt.j
use io; use json; use os;
import "@deckyard/openai/" as openai;

def key as string init os.getEnv("OPENAI_API_KEY");
def c as openai.Client init openai.client($key);   # OPENAI_API_KEY
if (os.hasEnv("OPENAI_BASE_URL")) {
    $c = openai.withBaseUrl($c, os.getEnv("OPENAI_BASE_URL"));
}
def req as json.Value init openai.newRequest("gpt-5.4-mini");
$req = openai.withSystem($req, "Answer in one sentence.");
$req = openai.addUserText($req, "Why is the sky blue?");
io.printf("%s\n", openai.text(openai.chat($c, $req)));

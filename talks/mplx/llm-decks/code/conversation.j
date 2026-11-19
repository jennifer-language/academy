# "A conversation: addReply", after the gemini deck's chat example.
# Run: GEMINI_API_KEY=... jennifer run conversation.j
use io; use json; use os;
import "@deckyard/gemini/" as gemini;

def c as gemini.Client init gemini.client(os.getEnv("GEMINI_API_KEY"));
if (os.hasEnv("GEMINI_BASE_URL")) {
    $c = gemini.withBaseUrl($c, os.getEnv("GEMINI_BASE_URL"));
}
def req as json.Value init gemini.newRequest("gemini-3.8-flash");
$req = gemini.withSystem($req, "Answer in one sentence.");
$req = gemini.addUserText($req, "Why is the sky blue?");
def reply as json.Value init gemini.chat($c, $req);
io.printf("%s\n\n", gemini.text($reply));
$req = gemini.addReply($req, $reply);
$req = gemini.addUserText($req, "Now explain it to a five-year-old.");
$reply = gemini.chat($c, $req);
io.printf("%s\n", gemini.text($reply));
io.printf("(%d turns in the request)\n", json.length($req, "/contents"));

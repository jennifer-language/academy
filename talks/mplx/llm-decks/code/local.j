# "OpenAI-compatible servers": one client for a local Ollama, one for
# Azure OpenAI. Run with Ollama (or fake.j) on 127.0.0.1:11434:
#   jennifer run local.j
# AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_KEY, when set, send the same
# question to an Azure deployment as well.
use io; use json; use os;
import "@deckyard/openai/" as openai;

def local as openai.Client init openai.withBaseUrl(
    openai.client(""), "http://127.0.0.1:11434/v1");
def req as json.Value init openai.addUserText(
    openai.newRequest("qwen3:4b"), "Why is the sky blue?");
io.printf("local: %s\n", openai.text(openai.chat($local, $req)));

# plain http to another host is refused unless withPlainHttp
def remote as openai.Client init openai.withBaseUrl(
    openai.client(""), "http://192.0.2.10:11434/v1");
try {
    openai.chat($remote, $req);
} catch (e) {
    io.printf("remote: %s (%s)\n", $e.kind, $e.message);
}

if (os.hasEnv("AZURE_OPENAI_ENDPOINT")) {
    def endpoint as string init os.getEnv("AZURE_OPENAI_ENDPOINT");
    def azureKey as string init os.getEnv("AZURE_OPENAI_KEY");
    def az as openai.Client init openai.azure($endpoint, $azureKey);
    io.printf("azure: %s\n", openai.text(openai.chat($az, $req)));
}

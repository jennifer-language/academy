# "Reading a reply": why each model stopped and the normalised Usage,
# from one question to each vendor. Run with the keys and base URLs set.
use io; use json; use os;
import "@deckyard/anthropic/" as anthropic;
import "@deckyard/openai/" as openai;
import "@deckyard/gemini/" as gemini;

def const Q as string init "Why is the sky blue?";

def ac as anthropic.Client init anthropic.client(os.getEnv("ANTHROPIC_API_KEY"));
if (os.hasEnv("ANTHROPIC_BASE_URL")) {
    $ac = anthropic.withBaseUrl($ac, os.getEnv("ANTHROPIC_BASE_URL"));
}
def oc as openai.Client init openai.client(os.getEnv("OPENAI_API_KEY"));
if (os.hasEnv("OPENAI_BASE_URL")) {
    $oc = openai.withBaseUrl($oc, os.getEnv("OPENAI_BASE_URL"));
}
def gc as gemini.Client init gemini.client(os.getEnv("GEMINI_API_KEY"));
if (os.hasEnv("GEMINI_BASE_URL")) {
    $gc = gemini.withBaseUrl($gc, os.getEnv("GEMINI_BASE_URL"));
}

def a as json.Value init anthropic.chat($ac,
    anthropic.addUserText(anthropic.newRequest("claude-opus-5-5"), Q));
def au as anthropic.Usage init anthropic.usage($a);
def o as json.Value init openai.chat($oc,
    openai.addUserText(openai.newRequest("gpt-5.4-mini"), Q));
def ou as openai.Usage init openai.usage($o);
def g as json.Value init gemini.chat($gc,
    gemini.addUserText(gemini.newRequest("gemini-3.8-flash"), Q));
def gu as gemini.Usage init gemini.usage($g);

io.printf("[%s, %d in, %d out]    [%s, %d in, %d out]    [%s, %d in, %d out]\n",
    anthropic.stopReason($a), $au.inputTokens, $au.outputTokens,
    openai.finishReason($o), $ou.inputTokens, $ou.outputTokens,
    gemini.finishReason($g), $gu.inputTokens, $gu.outputTokens);
# no answer: a refusal is not an error
io.printf("refusal: openai \"%s\", gemini block reason \"%s\"\n",
    openai.refusal($o), gemini.blockReason($g));
io.printf("totals: %d %d %d, cached %d, reasoning %d\n", $au.totalTokens,
    $ou.totalTokens, $gu.totalTokens, $au.cachedTokens, $gu.reasoningTokens);

# "What actually goes on the wire": the three requests, as JSON.
# Needs no key and sends nothing. Run: jennifer run wire.j
use io; use json;
import "@deckyard/anthropic/" as anthropic;
import "@deckyard/openai/" as openai;
import "@deckyard/gemini/" as gemini;

def a as json.Value init anthropic.newRequest("claude-opus-5-5");
$a = anthropic.withSystem($a, "Answer in one sentence.");
$a = anthropic.addUserText($a, "Why is the sky blue?");
io.printf("anthropic %s\n", json.encode($a));

def o as json.Value init openai.newRequest("gpt-5.4-mini");
$o = openai.withSystem($o, "Answer in one sentence.");
$o = openai.addUserText($o, "Why is the sky blue?");
io.printf("openai    %s\n", json.encode($o));

def g as json.Value init gemini.newRequest("gemini-3.8-flash");
$g = gemini.withSystem($g, "Answer in one sentence.");
$g = gemini.addUserText($g, "Why is the sky blue?");
io.printf("gemini    %s\n", json.encode($g));

# What is left of GitHub's hourly REST budget for this address: one
# anonymous read of /rate_limit, which does not count against it.
use io;

import "@deckyard/codehost/" as codehost;
import "@deckyard/github/" as github;

def f as codehost.Forge init codehost.connect("github", "github.com", "");
def rl as github.RateLimit init github.rateLimit($f.github);
io.printf("%d of %d left\n", $rl.remaining, $rl.limit);

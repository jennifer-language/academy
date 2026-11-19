# Plain http to a forge on the LAN: refused before anything is sent,
# unless the client opts in. No token leaves this machine here.
use io;

import "@deckyard/codehost/" as codehost;
import "@deckyard/forgejo/" as forgejo;

/**
 * Read a repository and say how it went.
 *
 * @param f {codehost.Forge} the forge
 */
func attempt(f as codehost.Forge) {
    try {
        codehost.repository($f, "relbot/tempo");
        io.printf("%s: read\n", $f.backend);
    } catch (e) {
        io.printf("%s: %s: %s\n", $f.backend, $e.kind, $e.message);
    }
}

def lan as string init "http://git.lan:3000";
attempt(codehost.connect("forgejo", $lan, "TOKEN"));
attempt(codehost.connect("github", "http://ghes.lan", "TOKEN"));
attempt(codehost.connect("gitlab", "http://git.lan:8929", "TOKEN"));
def c as forgejo.Client init forgejo.withToken(forgejo.client($lan), "TOKEN");
attempt(codehost.fromForgejo(forgejo.withPlainHttp($c)));

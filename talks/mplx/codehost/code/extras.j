# Settings connect does not take, and a verb only the backends have.
# Builds the forges and prints them; with --kick it also starts CI on
# main (tempo has no workflow or pipeline, so the forges refuse it).
use io;
use os;

import "@deckyard/codehost/" as codehost;
import "@deckyard/forgejo/" as forgejo;
import "@deckyard/github/" as github;
import "@deckyard/gitlab/" as gitlab;

/**
 * Start the release workflow or pipeline on main.
 *
 * @param f {codehost.Forge} the forge
 * @param repo {string} the repository
 */
func kick(f as codehost.Forge, repo as string) {
    match ($f.backend) {
        when "github" {
            github.dispatchWorkflow($f.github, $repo, "release.yml",
                "main", {});
        }
        when "gitlab" {
            gitlab.runPipeline($f.gitlab, $repo, "main", {});
        }
        when "forgejo" {
            forgejo.dispatchWorkflow($f.forgejo, $repo, "release.yml",
                "main", {});
        }
    }
}

def gl as gitlab.Client init gitlab.client("http://127.0.0.1:18929");
$gl = gitlab.withToken($gl, os.getEnv("GITLAB_TOKEN"));
$gl = gitlab.withRetries(gitlab.withTimeout($gl, 60000), 3);
def fj as forgejo.Client init forgejo.client("http://127.0.0.1:13300");
$fj = forgejo.withRetries(forgejo.withToken($fj,
    os.getEnv("FORGEJO_TOKEN")), 3);
def sites as list of codehost.Forge init [
    codehost.fromGitlab($gl), codehost.fromForgejo($fj)];
for (def f in $sites) {
    io.printf("%s: ready\n", $f.backend);
    if (len(os.ARGS) > 1 and os.ARGS[1] == "--kick") {
        kick($f, "relbot/tempo");
    }
}

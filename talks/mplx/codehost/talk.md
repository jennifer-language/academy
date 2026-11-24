---
theme: carbon
ratio: 16:9
transition: slide
---

# One API over GitHub™, GitLab™ and Forgejo™

![Jennifer](jennifer-logo.png)

One Jennifer script that releases a project on every forge it is
mirrored to: notes, a CI gate, assets, and a check of what landed.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
This talk is about the forge APIs, not about CI: the pipeline that runs on
GitHub™, Gitea™ and Forgejo™ has its own talk. We use the codehost deck and the
three decks under it to do the work that otherwise means clicking through two
or three web interfaces. Every output on the slides is from a real run with
the released 0.27.0 interpreter and the released decks: against Forgejo 13.0.5
and GitLab™ CE 19.5.5 in throwaway local containers, and against a small GitHub
stand-in written in Jennifer, as no real GitHub account was touched.
-->

---

## Why one API

- Every Jennifer repository has two remotes: **GitHub** and the project's
  own Forgejo at [git.jennifer-lang.dev](https://git.jennifer-lang.dev/)
- Nothing mirrors between them: each push, tag and release happens twice
- Same job, three dialects: pull vs merge request, `open` vs `opened`,
  asset vs release link, 409 vs 422
- **@deckyard/codehost**: one verb, the right backend, one shape back

CI on all of them: [One CI pipeline for GitHub, Gitea and Forgejo](https://academy.jennifer-lang.dev/talks/mplx/forge-ci/)

<!-- notes:
The project keeps each repository on GitHub and on its own Forgejo, and pushes
to each by hand. A release therefore means two release pages, two uploads and
two places where a typo can slip in. The forges do the same things with
different words and different JSON. codehost hides those differences behind
one set of verbs, so the release becomes a loop over a list of forges. The CI
side, one workflow file for all forges, is covered in the forge-ci talk.
-->

---

## Four decks, one import

| Deck | Version | Talks to | Its error |
| --- | --- | --- | --- |
| `@deckyard/codehost` | 0.3.0 | the three below | `CodehostError` |
| `@deckyard/github` | 0.3.0 | github.com, Enterprise Server | `GithubError` |
| `@deckyard/gitlab` | 0.4.0 | gitlab.com, self-managed | `GitlabError` |
| `@deckyard/forgejo` | 0.4.0 | Forgejo, Codeberg™, Gitea | `ForgejoError` |
| `@deckyard/git` | 0.2.0 | the local `git` program | `Error{kind: "git"}` |

```sh
jvc add @deckyard/codehost && jvc add @deckyard/git && jvc install
```

<!-- notes:
codehost is a facade: it holds no HTTP code of its own beyond one call, it
picks the verb of the right backend deck and normalises the answer. jvc
installs the three backends with it, so vendor ends up with five decks,
counting git. codehost needs only the net capability; the git deck needs exec,
since it runs the git program. Gitea speaks Forgejo's API, so it goes through
the forgejo deck. Deck sources and manuals: github.com/deckyard.
-->

---

## A Forge from configuration

```toml
[[forge]]
backend = "forgejo"
host = "http://127.0.0.1:13300"
repo = "relbot/tempo"
token = "FORGEJO_TOKEN"       # the variable, never the token
```

```jennifer excerpt
def f as codehost.Forge init codehost.connect(
    toml.asString($doc, $p + "/backend"),
    toml.asString($doc, $p + "/host"),
    os.getEnv(toml.asString($doc, $p + "/token")));
```

<!-- notes:
connect takes the backend by name, a host and a token, with an empty token
for anonymous reads. Because the backend is a string, it can come from a
file: forges.j in the talk's code reads forges.toml, one table per forge, and
returns a list of sites, each a Forge and the repository's path on it. The
token stays in the environment. A Forge holds the backend's own client, which
we will use later for what only one forge can do.
-->

---

## One loop, three forges

```jennifer excerpt
for (def s in forges.load()) {
    def f as codehost.Forge init $s.forge;
    def r as codehost.Repository init codehost.repository($f, $s.repo);
    ...
    for (def i in codehost.issues($f, $s.repo, "open")) {
        ...
    }
}
```

```text
github: relbot/tempo, default branch main
  #7 Duration parser drops seconds [bug]
forgejo: relbot/tempo, default branch main
  #1 Duration parser drops seconds []
```

<!-- notes:
repos.j, the first program: the same two verbs on every forge, printing the
repository and each open issue. The output is
cut to one issue per forge; GitLab answers the same as Forgejo. The issue
numbers differ, since mirrored repositories do not share issues, and the
labels are missing outside GitHub. Both matter later, when we sync labels.
The github line comes from the stand-in, which serves the same JSON shape as
a GitHub Enterprise Server under api v3.
-->

---

## What codehost normalises

| | GitHub | GitLab | Forgejo | codehost |
| --- | --- | --- | --- | --- |
| issue state | `open` | `opened` | `open` | `open`, `closed` |
| change request | pull request | merge request, `iid` | pull request | `ChangeRequest` |
| draft | flag | `Draft:` prefix | `WIP:` prefix | `isDraft` |
| CI states | 4 | 6 to set, more read | 5 | `pending` `success` `failure` `error` |
| release asset | asset | link to a package | attachment | `Asset` |

<!-- notes:
The deck decides once what each concept means. A merged pull request is
closed with a merged flag on GitHub and Forgejo, merged on GitLab; codehost
says merged. GitLab's running and canceled become pending and error, with the
original word kept in forgeState. Forgejo's warning reads as success. A GitLab
release has no id; the tag is its key, so Release.id is zero there, which you
will see in a moment. Labels named on an issue are created when missing, on
every forge.
-->

---

## Change requests

```jennifer excerpt
def c as codehost.ChangeRequest init codehost.createChangeRequest(
    $f, $s.repo, $fix, "main", "Print 0s for zero", "Fixes #1.", true);
...
codehost.mergeChangeRequest($f, $s.repo, $c.number, "rebase", true);
```

```text
forgejo: !3 Print 0s for zero, open, draft true, mergeable false
forgejo: forgejo: POST /repos/relbot/tempo/pulls/3/merge: HTTP 405:
  Work in progress PRs cannot be merged
gitlab: !1 Print 0s for zero, open, draft true, mergeable false
gitlab: codehost: GitLab merges with the project's merge method;
  rebase is a project setting there, not a merge style
```

<!-- notes:
pulls.j creates a branch, commits a file with writeFile and opens a draft on
Forgejo and GitLab; the GitHub stand-in has no pull requests. The deck sends
the title as WIP colon on Forgejo and Draft colon on GitLab, and hands it back
without the prefix and with isDraft set. Forgejo numbers pull requests with
the issues, hence 3. The rebase merge is refused twice: by Forgejo for the
draft, and by codehost itself on GitLab, before any request. Long lines wrapped.
-->

---

## Releases with assets

| Verb | Does |
| --- | --- |
| `createRelease(f, repo, tag, target, name, body, pre)` | the tag too, at `target` |
| `uploadAsset(f, repo, release, name, data)` | GitLab: package + link |
| `release(f, repo, tag)` / `latestRelease(f, repo)` | read one |
| `downloadAsset(f, asset, maxBytes)` | with the token, own host only |

```text
github: id 101, 2 assets
forgejo: id 2, 2 assets
gitlab: id 0, 2 assets
  SHA256SUMS, size 0
  tempo-1.3.0.tar.gz, size 0
```

<!-- notes:
Four verbs cover releases. uploadAsset takes the Release, since GitHub and
Forgejo address it by id and GitLab by tag. On GitLab an asset is a link, so
the deck puts the file into the project's generic package registry and links
it, as glab does. GitLab lists no sizes, and has no pre-releases: asking for
one is refused. The output is from show.j; the asset lines of GitHub and
Forgejo are left out, both report the sizes 330 and 85.
-->

---

## The release script

```text
jennifer run release.j work/tempo 1.3.0 \
    work/dist/tempo-1.3.0.tar.gz work/dist/SHA256SUMS
```

1. **Notes** from the local history, with `@deckyard/git`
2. **Gate**: refuse unless CI passed on the tagged commit, everywhere
3. **Release** and upload the files, forge by forge
4. **Read back** every file and compare its SHA-256

Nothing is created until every forge is green.

<!-- notes:
release.j is about a hundred lines. The tag exists locally and main is pushed
to every forge, as the project does by hand today. The script does not push
tags: createRelease creates the tag on the forge at the commit we name, which
keeps the token-carrying work inside one program. The order matters: all
checks first, then all writes, then a read back, so a red forge stops the
release before anything exists anywhere.
-->

---

## Notes from git, not from memory

```jennifer excerpt
    def prev as string init git.describe($r, $newTag + "~1");
    $prev = regex.replace('-[0-9]+-g[0-9a-f]+$', $prev, "");
    def text as string init "Changes since " + $prev + ":\n\n";
    for (def c in git.log($r, $prev + ".." + $newTag, "", 0)) {
        $text = $text + "- " + $c.subject + "\n";
    }
```

```text
Changes since 1.2.0:

- docs: the --sum flag (#9)
- format: print 0s for zero
- parse: keep seconds (#7)
```

<!-- notes:
The git deck runs the git program with hardened defaults: no hooks, and only
https and ssh remotes unless withProtocols allows more. describe of the
commit before the tag names the previous tag plus a distance suffix, which the
regex removes. log takes a range and returns Commit structs, newest first.
The notes shown are what the forges stored, read back from Forgejo afterwards.
Every failure in the git deck is kind git, or timeout and limit.
-->

---

## The gate: every check, every forge

```jennifer excerpt
func notGreen(s as forges.Site, commit as string) {
    def seen as list of string init [];
    def all as list of codehost.CommitStatus init
        codehost.commitStatuses($s.forge, $s.repo, $commit);
    for (def st in $all) {
        if (not lists.contains($seen, $st.context)) {
            $seen[] = $st.context;
            if ($st.state != "success") {
                return $st.context + " is " + $st.state;
            }
        }
    }
```

<!-- notes:
commitStatuses lists every status ever set on the commit, newest first, so
the first one per context is the current one. The function returns the first
check that is not green, and a commit with no checks at all also counts as not
green. Matching on the four normalised states is what makes this one function
instead of three; forgeState would tell GitLab's running from its pending if
you cared. Statuses take a full SHA, as GitLab needs one.
-->

---

## A red gate

```text
$ jennifer run ci.j 9bc7e6f9efe8469c4600e486b26659d49922249b \
    ci/check pending
github: ci/check pending (pending)
forgejo: ci/check pending (pending)
gitlab: ci/check pending (pending)
$ jennifer run release.j work/tempo 1.3.0 work/dist/...
github: ci/check is pending at 9bc7e6f
forgejo: ci/check is pending at 9bc7e6f
gitlab: ci/check is pending at 9bc7e6f
not released
```

<!-- notes:
ci.j stands in for the CI systems: it sets a commit status through
setCommitStatus on each forge, which is exactly what a CI job reports. The
value in parentheses is forgeState, the forge's own word. With the check still
pending everywhere, the release script lists every forge that is not ready
and exits with status 1, before it has created a tag or a release anywhere.
-->

---

## Release, upload, read back

```jennifer excerpt
def r as codehost.Release init codehost.createRelease(
    $f, $s.repo, $tag, $sha, $tag, $notes, false);
for (def file in $files) {
    def data as bytes init fs.readBytes($file);
    codehost.uploadAsset($f, $s.repo, $r, path.base($file), $data);
}
...
for (def a in $r.assets) {
    def got as bytes init codehost.downloadAsset($f, $a, 0);
    if (sha256($got) != $want[$a.name]) {
        stop($f.backend + ": " + $a.name + " differs");
    }
```

<!-- notes:
The target is the commit SHA from git, not a branch, so a push to main in the
meantime cannot move the release. The read back calls release again instead
of trusting the objects the writes returned, and downloads each asset with
the token. maxBytes zero means the default cap of 64 MiB; a bigger file is
kind limit. sha256 is hash.compute and encoding.toText with hex.
-->

---

## A green run

```text
$ jennifer run ci.j 9bc7e6f9efe8469c4600e486b26659d49922249b \
    ci/check success
$ jennifer run release.j work/tempo 1.3.0 work/dist/...
github: released http://127.0.0.1:18080/relbot/tempo/releases/tag/1.3.0
forgejo: released http://127.0.0.1:13300/relbot/tempo/releases/tag/1.3.0
gitlab: released http://127.0.0.1:18929/relbot/tempo/-/releases/1.3.0
github: tempo-1.3.0.tar.gz ok, 330 bytes
forgejo: tempo-1.3.0.tar.gz ok, 330 bytes
gitlab: tempo-1.3.0.tar.gz ok, 330 bytes
```

<!-- notes:
The same command after the check turned green. Three release pages, each with
the tarball and the checksum file, and each file read back identical. The
SHA256SUMS lines are left out here, three more lines saying ok, 85 bytes.
The run took under three seconds. Run it a second time and every forge refuses
the duplicate, which is the next slide but one.
-->

---

## Sync labels, then label issues

```jennifer excerpt
for (def l in $wanted) {
    if (not lists.contains($have, $l.name)) {
        codehost.createLabel(
            $f, $s.repo, $l.name, $l.color, $l.description);
        io.printf("%s: created %s\n", $f.backend, $l.name);
    }
}
```

```text
forgejo: created bug              gitlab: created bug
forgejo: created release-blocker  gitlab: created release-blocker
forgejo: created docs             gitlab: created docs
forgejo: #2 docs                  gitlab: #2 docs
forgejo: #1 bug                   gitlab: #1 bug
```

<!-- notes:
labels.j copies the labels of the first forge, colour and description
included, to the others, then matches open issues by title and sets the same
labels with setIssueLabels. Run twice, the second run prints only the issue
lines: nothing to create. Forgejo itself drops a label name it does not know,
so codehost creates missing ones there; GitHub and GitLab do it themselves.
GitLab refuses a label name with a comma. Output in two columns.
-->

---

## Errors: one struct per deck

```jennifer excerpt
} catch (e) {
    if ($e.kind != codehost.ERROR_KIND) {
        throw $e;
    }
    def ce as codehost.CodehostError init $e;
    io.printf("%s %d: %s\n", $ce.backend, $ce.status, $ce.message);
}
```

```text
github 422: github: POST /repos/relbot/tempo/releases: HTTP 422:
  Validation Failed (tag_name already_exists)
forgejo 409: forgejo: POST /repos/relbot/tempo/releases: HTTP 409:
  Release has no Tag
gitlab 409: gitlab: POST /projects/relbot%2Ftempo/releases: HTTP 409:
  Release already exists
```

<!-- notes:
errors.j releases 1.3.0 again. Each backend throws its own struct, kind
github, gitlab or forgejo, with message and status; codehost rebuilds it as
one CodehostError with the backend added. Match the kind, then read the
fields, never the message: Forgejo's text here is plainly wrong, its 409 is
right. The same duplicate is 422 on GitHub, so a caller checks the status per
backend. The generic kinds limit, timeout, closed, cancelled and net pass
through untouched.
-->

---

## Tokens and scopes

| Needs | GitHub, fine-grained | GitLab | Forgejo, Gitea |
| --- | --- | --- | --- |
| read | Contents read | `read_api` | `read:repository` |
| issues, labels | Issues | `api` | `write:issue` |
| releases, files | Contents write | `api` | `write:repository` |
| statuses | Commit statuses | `api` | `write:repository` |

```text
forgejo 403: ... HTTP 403: token does not have at least one of
  required scope(s): [write:repository]
gitlab 403: ... HTTP 403: insufficient_scope: The request requires
  higher privileges than provided by the access token.
```

<!-- notes:
A release bot needs write access, an audit script only read access, so give
each program its own token. The output is errors.j again, with read-only
tokens on Forgejo and GitLab; the GitHub stand-in checks no tokens, so it is
left out. GitLab also takes OAuth tokens with withBearer and CI_JOB_TOKEN with
withJobToken, which reaches releases and packages from inside a pipeline.
Anonymous clients read public data only.
-->

---

## Paging and rate limits differ

| | GitHub | GitLab | Forgejo |
| --- | --- | --- | --- |
| page | 100, `Link` | 100, `X-Next-Page` | 50, `X-Total-Count` |
| budget | 60 / h anonymous, 5000 with a token | the instance's | the instance's |
| `withRetries` | GETs: 5xx, waits up to 60 s | GETs: 429, 5xx, up to 30 s | GETs: 429, 5xx |

Every deck stops after 1000 pages with kind `"limit"`.

```text
$ jennifer run ratelimit.j
52 of 60 left
```

<!-- notes:
Listing verbs read every page for you, each backend the way its forge pages;
GitLab's keyset-paged lists follow the Link header instead. Past a thousand
pages a list stops with kind limit instead of running forever. The GitHub and
GitLab retries honour the wait the server states.
GitHub's anonymous budget is small: ratelimit.j asked the real github.com,
anonymously, through github.rateLimit, which does not count against it.
codehost never retries and connect builds clients without retries; writes are
never retried by any deck, since they need not be idempotent.
-->

---

## Plain http is an opt-in

```text
forgejo: codehost: forgejo: plain http to "git.lan" would send
  the token in clear: use https, or withPlainHttp
github: codehost: github: plain http to "ghes.lan" would send
  the token in clear: use https, or withPlainHttp
gitlab: net: net.connect: git.lan:8929: dial tcp: lookup git.lan
  on 127.0.0.53:53: no such host
forgejo: net: net.connect: git.lan:3000: dial tcp: lookup ...
```

```jennifer excerpt
def c as forgejo.Client init forgejo.withToken(forgejo.client($lan), "TOKEN");
attempt(codehost.fromForgejo(forgejo.withPlainHttp($c)));
```

<!-- notes:
A token over plain http can be read by anyone on the path. The github and
forgejo decks allow http only to this machine, which is why the local
containers work, and refuse any other host before a byte is sent. The opt-in,
last line, gets past the check and fails only because git.lan does not
exist here. gitlab 0.4.0 has no such check: it tried to connect, token and
all. connect has no opt-in; wrap a client with fromForgejo or fromGithub.
-->

---

## Beyond the common verbs

```jennifer excerpt
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
```

<!-- notes:
codehost covers what all forges share. Workflows and pipelines, reviews,
milestones, webhooks, members, GraphQL™ and raw endpoints stay in the backend
decks, and the Forge carries the backend's client, so they are one match away
with the same token. The same route serves settings connect does not take:
build the client with withTimeout, withRetries or withCaCert and wrap it with
fromGitlab, fromGithub or fromForgejo. extras.j in the code does both.
-->

---

## Checklist and read more

- Forges in a config file, tokens in the environment, one per job
- Check everything first, write second, read back third
- Pin releases to a commit SHA, not a branch
- Match `kind`, then `status` per `backend`; never the message
- https everywhere; `withPlainHttp` only on a trusted LAN

Decks: [codehost](https://registry.jennifer-lang.dev/deck/deckyard/codehost),
[git](https://registry.jennifer-lang.dev/deck/deckyard/git); talks:
[forge CI](https://academy.jennifer-lang.dev/talks/mplx/forge-ci/),
[your first deck](https://academy.jennifer-lang.dev/talks/mplx/first-deck/)

<!-- notes:
The talk's code folder holds every program shown, the GitHub stand-in, the
setup script and the docker lines for Forgejo and GitLab, so you can repeat
every run on your own machine without touching a real account. The codehost
manual has the full normalisation table and the per-forge differences. If you
release on one forge only, the backend deck alone is enough; codehost pays off
from the second forge on.
-->

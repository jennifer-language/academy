# Cut one release on every forge in forges.toml: notes from the local
# history, a CI gate, the release with its files, then a check that
# each forge serves exactly those bytes.
#   jennifer run release.j <checkout> <tag> <file>...
use convert;
use encoding;
use fs;
use hash;
use io;
use lists;
use os;
use path;
use regex;

import "./forges.j" as forges;
import "@deckyard/codehost/" as codehost;
import "@deckyard/git/" as git;

/**
 * The release notes: one line per commit since the previous tag.
 *
 * @param r {git.Repo} the checkout
 * @param newTag {string} the new tag
 * @return {string} the notes, Markdown
 */
func notesFor(r as git.Repo, newTag as string) {
    def prev as string init git.describe($r, $newTag + "~1");
    $prev = regex.replace('-[0-9]+-g[0-9a-f]+$', $prev, "");
    def text as string init "Changes since " + $prev + ":\n\n";
    for (def c in git.log($r, $prev + ".." + $newTag, "", 0)) {
        $text = $text + "- " + $c.subject + "\n";
    }
    return $text;
}

/**
 * Why a commit is not green on a forge: "" when every check passed.
 *
 * @param s {forges.Site} the forge
 * @param commit {string} the commit
 * @return {string} the reason, or ""
 */
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
    if (len($seen) == 0) {
        return "no checks reported";
    }
    return "";
}

/**
 * The SHA-256 of some bytes, in hex.
 *
 * @param data {bytes} the bytes
 * @return {string} the digest
 */
func sha256(data as bytes) {
    return encoding.toText("hex", hash.compute("sha256", $data));
}

/**
 * Stop with an error of kind "release".
 *
 * @param message {string} what went wrong
 */
func stop(message as string) {
    throw Error{kind: "release", message: $message};
}

if (len(os.ARGS) < 4) {
    stop("usage: release.j <checkout> <tag> <file>...");
}
def tag as string init os.ARGS[2];
def files as list of string init os.ARGS[3..len(os.ARGS)];
def repo as git.Repo init git.open(git.config(), os.ARGS[1]);
def sha as string init git.revParse($repo, $tag);
def notes as string init notesFor($repo, $tag);
def sites as list of forges.Site init forges.load();
def want as map of string to string init {};
for (def file in $files) {
    $want[path.base($file)] = sha256(fs.readBytes($file));
}

# 1. the gate: every forge's CI passed on the tagged commit
def red as int init 0;
for (def s in $sites) {
    def why as string init notGreen($s, $sha);
    if ($why != "") {
        io.printf("%s: %s at %s\n", $s.forge.backend, $why, $sha[0..7]);
        $red = $red + 1;
    }
}
if ($red > 0) {
    io.printf("not released\n");
    exit 1;
}

# 2. the release and its files, forge by forge
for (def s in $sites) {
    def f as codehost.Forge init $s.forge;
    def r as codehost.Release init codehost.createRelease(
        $f, $s.repo, $tag, $sha, $tag, $notes, false);
    for (def file in $files) {
        def data as bytes init fs.readBytes($file);
        codehost.uploadAsset($f, $s.repo, $r, path.base($file), $data);
    }
    io.printf("%s: released %s\n", $f.backend, $r.htmlUrl);
}

# 3. read it back: every file there, byte for byte
for (def s in $sites) {
    def f as codehost.Forge init $s.forge;
    def r as codehost.Release init codehost.release($f, $s.repo, $tag);
    if (len($r.assets) != len($want)) {
        stop($f.backend + ": " + convert.toString(len($r.assets)) + " files");
    }
    for (def a in $r.assets) {
        def got as bytes init codehost.downloadAsset($f, $a, 0);
        if (sha256($got) != $want[$a.name]) {
            stop($f.backend + ": " + $a.name + " differs");
        }
        io.printf("%s: %s ok, %d bytes\n", $f.backend, $a.name, len($got));
    }
}

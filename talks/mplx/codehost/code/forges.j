# The forges tempo is mirrored to, read from forges.toml.
use convert;
use fs;
use os;
use toml;

import "@deckyard/codehost/" as codehost;

/** A forge and the repository on it. */
export def struct Site {
    forge as codehost.Forge,
    repo as string
};

/**
 * Connect to every forge in the configuration: the TOML file `FORGES`
 * names, by default `forges.toml`.
 *
 * @return {list of Site} the forges, in the file's order
 */
export func load() {
    def file as string init "forges.toml";
    if (os.getEnv("FORGES") != "") {
        $file = os.getEnv("FORGES");
    }
    def doc as toml.Value init toml.decode(fs.readString($file));
    def out as list of Site init [];
    for (def i in 0..toml.length($doc, "/forge")) {
        def p as string init "/forge/" + convert.toString($i);
        def f as codehost.Forge init codehost.connect(
            toml.asString($doc, $p + "/backend"),
            toml.asString($doc, $p + "/host"),
            os.getEnv(toml.asString($doc, $p + "/token")));
        $out[] = Site{forge: $f, repo: toml.asString($doc, $p + "/repo")};
    }
    return $out;
}

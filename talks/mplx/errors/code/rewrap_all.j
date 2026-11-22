# "Rewrapping hides the generic kinds": the wrapper turns the decoder's
# nesting cap (kind "limit") into its own kind "config".
use io;
use json;
use strings;

func loadConfig(text as string) {
    try {
        return json.decode($text);
    } catch (e) {
        throw Error{kind: "config", message: $e.message};
    }
}

try {
    loadConfig(strings.replicate("[", 5000));
} catch (e) {
    io.printf("%s | %s\n", $e.kind, $e.message);
}

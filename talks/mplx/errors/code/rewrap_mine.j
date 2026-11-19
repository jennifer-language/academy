# "Rewrap only what is yours": the generic kinds pass through, everything
# else becomes kind "config" with the decoder's message kept.
use io;
use json;
use strings;

func loadConfig(text as string) {
    try {
        return json.decode($text);
    } catch (e) {
        match ($e.kind) {
            when "limit", "timeout", "closed", "cancelled", "net" {
                throw $e;
            }
        }
        throw Error{kind: "config", message: $e.message};
    }
}

for (def text in [strings.repeat("[", 5000), '{"port": 80']) {
    try {
        loadConfig($text);
    } catch (e) {
        io.printf("%s | %s\n", $e.kind, $e.message);
    }
}

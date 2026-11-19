# The fixed wrapper: the generic kinds pass through unchanged, only
# malformed input becomes kind "config". Both tests in config_test.j pass.
use json;

func load(text as string) {
    try {
        return json.decode($text);
    } catch (e) {
        match ($e.kind) {
            when "limit", "timeout", "closed", "cancelled", "net" { throw $e; }
            else {
                throw Error{kind: "config", message: "config: " + $e.message};
            }
        }
    }
}

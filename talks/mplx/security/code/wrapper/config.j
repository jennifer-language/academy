# The naive wrapper: every error from json.decode becomes kind "config",
# the cap's "limit" included. config_test.j next to this file catches it.
use json;

func load(text as string) {
    try {
        return json.decode($text);
    } catch (e) {
        throw Error{kind: "config", message: "config: " + $e.message};
    }
}

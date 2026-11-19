use strings;
use testing;
# config_test.j, beside a config.j whose load() wraps json.decode
func deepConfig() { load(strings.repeat("[", 5000)); }
func brokenConfig() { load("[1, 2"); }

func testCapStaysLimit() {
    testing.assertThrows("deepConfig", "limit");
}
func testMalformedIsConfig() {
    testing.assertThrows("brokenConfig", "config");
}

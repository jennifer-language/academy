use io;
use json;
use toml;
use yaml;
use time;

def y as yaml.Value init yaml.decode("country: NO\nanswer: yes\nversion: 1.10\nat: 12:30\nempty:\nzip: '01234'\nport: \"8080\"\nbig: 123456789012345678901\n");
for (def k in yaml.keys($y)) {
    io.printf("yaml %s -> %s\n", $k, yaml.typeOf($y, "/" + $k));
}
io.printf("version = %v\n", yaml.asFloat($y, "/version"));
try { yaml.asInt($y, "/port"); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
io.printf("big = %s\n", yaml.asString($y, "/big"));

def j as json.Value init json.decode('{"a": 1, "b": 1.0, "c": 1e2, "big": 123456789012345678901}');
for (def k in json.keys($j)) {
    io.printf("json %s -> %s\n", $k, json.typeOf($j, "/" + $k));
}
io.printf("%s\n", json.encode({"f": 2.0, "g": 1000000.0, "h": 0.1}));
io.printf("%v\n", json.asFloat($j, "/big"));

def t as toml.Value init toml.decode("d = 2026-11-19\nlt = 07:30:00\nhex = 0xff\nn = 1_000\n[[item]]\nsku = \"A1\"\n[[item]]\nsku = \"B2\"\n");
for (def k in toml.keys($t)) {
    io.printf("toml %s -> %s\n", $k, toml.typeOf($t, "/" + $k));
}
io.printf("%s\n", time.iso(toml.asDatetime($t, "/d")));
io.printf("%s", toml.encode($t));
try { toml.encode({"a": null}); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
try { toml.encode([1, 2]); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }

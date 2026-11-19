use io;
use fs;
use json;
use toml;
use yaml;

def t as toml.Value init toml.decode(fs.readString("app.toml"));
try { io.printf("%s", yaml.encodePretty($t)); } catch (e) { io.printf("%s\n", $e.message); }
def j as json.Value init json.decode(fs.readString("app.json"));
try { io.printf("%s", toml.encode($j)); } catch (e) { io.printf("%s\n", $e.message); }
io.printf("%v\n", toml.decode(toml.encode($t)) == $t);
io.printf("%v\n", json.decode(json.encode($j)) == $j);
def y as yaml.Value init yaml.decode(fs.readString("app.yaml"));
io.printf("%s", yaml.encodePretty($y));
io.printf("%s\n", yaml.encode($y));
io.printf("%v\n", yaml.decode(yaml.encodePretty($y)) == $y);
io.printf("%v\n", yaml.decode(yaml.encode($y)) == $y);
io.printf("%s", toml.encode($t));

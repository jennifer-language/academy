use io;
use json;
use toml;
use yaml;
use xml;
use convert;

def struct Db { host as string, pool as int };
def struct Config { name as string, port as int, tags as list of string, db as Db };

def c as Config init Config{name: "shop", port: 8080, tags: ["web", "eu"],
    db: Db{host: "localhost", pool: 4}};

io.printf("%s\n", json.encode($c));
io.printf("%s\n", yaml.encode($c));
try { io.printf("%s", toml.encode($c)); } catch (e) { io.printf("%s\n", $e.message); }

def x as xml.Value init xml.element("app");
$x = xml.setAttr($x, "name", $c.name);
$x = xml.setAttr($x, "port", convert.toString($c.port));
for (def t in $c.tags) {
    $x = xml.append($x, xml.setText(xml.element("tag"), $t));
}
io.printf("%s\n", xml.encode($x));

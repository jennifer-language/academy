use io;
use fs;
use json;
use toml;
use yaml;
use xml;
use convert;

def struct Config { name as string, port as int, debug as bool, pool as int };

def j as json.Value init json.decode(fs.readString("app.json"));
def a as Config init Config{name: json.asString($j, "/name"),
    port: json.asInt($j, "/port"), debug: json.asBool($j, "/debug"),
    pool: json.asInt($j, "/db/pool")};

def t as toml.Value init toml.decode(fs.readString("app.toml"));
def b as Config init Config{name: toml.asString($t, "/name"),
    port: toml.asInt($t, "/port"), debug: toml.asBool($t, "/debug"),
    pool: toml.asInt($t, "/db/pool")};

def y as yaml.Value init yaml.decode(fs.readString("app.yaml"));
def c as Config init Config{name: yaml.asString($y, "/name"),
    port: yaml.asInt($y, "/port"), debug: yaml.asBool($y, "/debug"),
    pool: yaml.asInt($y, "/db/pool")};

def x as xml.Value init xml.decode(fs.readString("app.xml"));
def d as Config init Config{name: xml.attr($x, "name"),
    port: convert.toInt(xml.attr($x, "port")),
    debug: xml.attr($x, "debug") == "true",
    pool: convert.toInt(xml.attr(xml.get($x, "db"), "pool"))};

io.printf("%v\n%v\n%v\n%v\n", $a, $b, $c, $d);
io.printf("%v\n", $a == $b and $b == $c and $c == $d);
io.printf("json %s, toml %s, yaml %s\n", json.typeOf($j, "/started"),
    toml.typeOf($t, "/started"), yaml.typeOf($y, "/started"));
io.printf("xml tags: %d\n", len(xml.findAll($x, "tag")));

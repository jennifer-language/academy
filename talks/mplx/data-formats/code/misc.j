use io;
use toml;
use xml;
use yaml;
def t as toml.Value init toml.decode("[[item]]\nsku = \"A1\"\n[[item]]\nsku = \"B2\"\n");
io.printf("%s\n", toml.asString($t, "/item/1/sku"));
def x as xml.Value init xml.decode("<a x=\"1\"/>");
try { xml.attr($x, "missing"); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
try { xml.decode("<a x=\"1\" x=\"2\"/>"); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
try { yaml.decode("a: 1\na: 2\n"); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
io.printf("%v\n", yaml.asInt(yaml.decode("p: 0x1F\n"), "/p"));

use io;
use json;
use toml;
use yaml;
use xml;

func show(label as string, e as Error) {
    io.printf("%s kind=%s msg=%s\n", $label, $e.kind, $e.message);
}

try { json.decode('{"port": 80,}'); } catch (e) { show("json", $e); }
try { json.decode('{"a": 1, "a": 2}'); } catch (e) { show("json", $e); }
try { toml.decode("port = 80\nport = 81\n"); } catch (e) { show("toml", $e); }
try { toml.decode("name = hello\n"); } catch (e) { show("toml", $e); }
try { yaml.decode("zip: 01234\n"); } catch (e) { show("yaml", $e); }
try { yaml.decode("a: [1, 2\n"); } catch (e) { show("yaml", $e); }
try { xml.decode("<a><b></a>"); } catch (e) { show("xml", $e); }
try { xml.decode("<a>&nbsp;</a>"); } catch (e) { show("xml", $e); }
def o as json.DecodeOptions;
$o.maxDepth = 3;
try { json.decodeWith("[[[[1]]]]", $o); } catch (e) { show("json", $e); }
try { json.asInt(json.decode('{"n": 1.0}'), "/n"); } catch (e) { show("json", $e); }
try { json.asString(json.decode('{"n": 1}'), "/m"); } catch (e) { show("json", $e); }

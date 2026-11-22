use io;
use json;
use yaml;
use xml;
use convert;
use strings;

try { convert.toInt(" 8080 "); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
def bomb as string init "a: &a [x, x, x, x, x, x, x, x, x, x]\n";
def prev as string init "a";
for (def i in 0..9) {
    def n as string init "b" + convert.toString($i);
    $bomb = $bomb + $n + ": &" + $n + " [*" + $prev + ", *" + $prev + ", *" + $prev
        + ", *" + $prev + ", *" + $prev + ", *" + $prev + ", *" + $prev + ", *" + $prev
        + ", *" + $prev + ", *" + $prev + "]\n";
    $prev = $n;
}
try { yaml.decode($bomb); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
try { yaml.decode("k: " + strings.replicate("x", 5000000)); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
def lol as string init "<!DOCTYPE l [<!ENTITY a \"aaaa\"><!ENTITY b \"&a;&a;\">]><l>&b;</l>";
try { xml.decode($lol); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
try { json.decode(strings.replicate("[", 2000)); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
try { xml.decode(strings.replicate("<a>", 2000)); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }

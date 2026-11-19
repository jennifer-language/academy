use io;
import "./sht31.j" as sht31;
def f as bytes;
for (def x in [0x66, 0x66, 0x93, 0x80, 0x00, 0xa2]) { $f[] = $x; }
def r as sht31.Reading init sht31.decode($f);
io.printf("%f|prec=1 C  %f|prec=1 %%RH\n", $r.celsius, $r.humidity);
$f[5] = 0xa3;
try { sht31.decode($f); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }

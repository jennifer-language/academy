import "snmp.j" as snmp;
use io;

def c as snmp.Client init snmp.clientWith("127.0.0.1:16161", "public",
    snmp.VERSION2C, 2000, 1);
def v as list of snmp.Varbind init snmp.get($c, ["1.3.6.1.2.1.1.3.0",
    "1.3.6.1.2.1.31.1.1.1.6.2"]);
io.printf("up %d ticks, %s [%s] %d\n", $v[0].number, $v[1].oid,
    $v[1].type, $v[1].number);
for (def vb in snmp.walk($c, "1.3.6.1.2.1.2.2.1.2")) {
    io.printf("%s = %s\n", $vb.oid, $vb.value);
}

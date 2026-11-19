import "snmp.j" as snmp;
use io;

def c as snmp.Client init snmp.clientWith("127.0.0.1:16170",
    "lab-ro-7f3a", snmp.VERSION2C, 1000, 1);
for (def vb in snmp.walk($c, "1.3.6.1.4.1.32473.1")) {
    io.printf("%s [%s] %s\n", $vb.oid, $vb.type, $vb.value);
}

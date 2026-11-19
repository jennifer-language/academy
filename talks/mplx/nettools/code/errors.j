import "ldap.j" as ldap;
import "ntp.j" as ntp;
import "snmp.j" as snmp;
import "transport.j" as transport;
use io;

try {
    def r as ntp.Result init ntp.queryWith("127.0.0.1:10124", 1000);
} catch (e) { io.printf("ntp closed: [%s] %s\n", $e.kind, $e.message); }
try {
    def c as snmp.Client init snmp.clientWith("127.0.0.1:16161", "wrong", snmp.VERSION2C, 500, 1);
    def v as list of snmp.Varbind init snmp.get($c, ["1.3.6.1.2.1.1.5.0"]);
} catch (e) { io.printf("snmp community: [%s] %s\n", $e.kind, $e.message); }
try {
    def c as snmp.Client init snmp.clientWith("127.0.0.1:16169", "public", snmp.VERSION2C, 500, 1);
    def v as list of snmp.Varbind init snmp.get($c, ["1.3.6.1.2.1.1.5.0"]);
} catch (e) { io.printf("snmp closed: [%s] %s\n", $e.kind, $e.message); }
try {
    def c as snmp.Client init snmp.clientWith("127.0.0.1:16161", "public", snmp.VERSION2C, 500, 1);
    def v as list of snmp.Varbind init snmp.get($c, ["1.3.6.1.2.1.1.99.0"]);
    io.printf("nosuch: %s [%s]\n", $v[0].oid, $v[0].type);
    def w as list of snmp.Varbind init snmp.set($c, [snmp.stringVar("1.3.6.1.2.1.1.5.0", "x")]);
} catch (e) { io.printf("snmp set: [%s] %s %d %s\n", $e.kind, $e.message, $e.errorStatus, $e.statusName); }
try {
    def c as ldap.Conn init ldap.connect("localhost:10390", transport.Security.Starttls);
} catch (e) { io.printf("ldap closed: [%s] %s\n", $e.kind, $e.message); }
try {
    def c as ldap.Conn init ldap.connect("localhost:10389", transport.Security.Tls);
} catch (e) { io.printf("ldap tls on plain port: [%s] %s\n", $e.kind, $e.message); }

import "ldap.j" as ldap;
import "transport.j" as transport;
use asn1;
use io;
use os;

def const BASE as string init "ou=people,dc=example,dc=org";
def c as ldap.Conn init ldap.connect("localhost:10389",
    transport.Security.Starttls);
ldap.bind($c, "cn=reader,dc=example,dc=org", os.getEnv("LDAP_PW"));
def f as asn1.Value init ldap.equals("objectClass", "inetOrgPerson");
def hits as list of ldap.Entry init ldap.searchPaged($c, BASE,
    ldap.SCOPE_ONE, $f, [], 20);
io.printf("paged by 20: %d entries\n", len($hits));
try {
    $hits = ldap.search($c, BASE, ldap.SCOPE_ONE, $f, []);
} catch (e) {
    io.printf("%s\n", $e.message);
}

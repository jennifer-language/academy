import "./dirauth.j" as dirauth;
import "ldap.j" as ldap;
import "transport.j" as transport;
use asn1;
use io;
use os;

def const BASE as string init "dc=example,dc=org";
def alice as string init "uid=alice,ou=people," + BASE;
def c as ldap.Conn init ldap.connect("localhost:10389",
    transport.Security.Starttls);
ldap.bind($c, "cn=reader," + BASE, os.getEnv("LDAP_PW"));
def who as string init "a*";
def f as asn1.Value init ldap.parseFilter("(uid="
    + ldap.escapeFilterValue($who) + ")");
def hits as list of ldap.Entry init ldap.search($c, BASE,
    ldap.SCOPE_SUB, $f, ["cn"]);
io.printf("%s: %d hits\n", ldap.escapeFilterValue($who), len($hits));
io.printf("groups: %a\n", dirauth.groupsOf($c, BASE, $alice));

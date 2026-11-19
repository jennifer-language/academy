import "./dirauth.j" as dirauth;
import "ldap.j" as ldap;
import "transport.j" as transport;
use io;
use os;

def const ADDR as string init "localhost:10389";
def const TLS as transport.Security init transport.Security.Starttls;
def const BASE as string init "dc=example,dc=org";
def c as ldap.Conn init ldap.connect(ADDR, TLS);
ldap.bind($c, "cn=reader," + BASE, os.getEnv("LDAP_PW"));
def dn as string init dirauth.userDn($c, BASE, "alice");
for (def pw in ["alice-pw-2026", "guess", ""]) {
    def ok as bool init dirauth.passwordOk(ADDR, TLS, $dn, $pw);
    io.printf("'%s': %v\n", $pw, $ok);
}
io.printf("eve: '%s'\n", dirauth.userDn($c, BASE, "eve"));

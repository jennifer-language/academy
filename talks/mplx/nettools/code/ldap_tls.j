import "ldap.j" as ldap;
import "transport.j" as transport;
use fs;
use io;
use net;
use os;

def const HOST as string init "localhost";
def const PLAIN as transport.Security init transport.Security.None;
def dn as string init "cn=reader,dc=example,dc=org";
def pw as string init os.getEnv("LDAP_PW");
def s as ldap.Conn init ldap.connect(HOST + ":10389",
    transport.Security.Starttls);
def o as net.TLSOptions;
$o.caCert = fs.readBytes("lab-ca.pem");
def t as ldap.Conn init ldap.Conn{timeoutMs: 5000,
    handle: net.connectTLS(HOST + ":10636", $o, 5000)};
def p as ldap.Conn init ldap.connect(HOST + ":10389", PLAIN);
def codes as list of int;
for (def c in [$s, $t, $p]) {
    $codes[] = ldap.bind($c, $dn, $pw).code;
}
io.printf("StartTLS, LDAPS, plain: %a\n", $codes);

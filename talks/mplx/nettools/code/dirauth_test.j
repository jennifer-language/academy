import "./dirauth.j" as dirauth;
import "ldap.j" as ldap;
import "transport.j" as transport;
use net;
use testing;

def const BASE as string init "dc=example,dc=org";
def const ALICE as string init "uid=alice,ou=people,dc=example,dc=org";
def const PLAIN as transport.Security init transport.Security.None;

func fixture() {
    return ldap.directory([
        ldap.entry(ALICE, {"objectClass": ["inetOrgPerson"],
            "uid": ["alice"],
            "userPassword": [ldap.password("pbkdf2", "s3cret")]}),
        ldap.group("cn=netops,ou=groups," + BASE, [ALICE])
    ]);
}

func testLoginAndGroups() {
    def l as net.Listener init ldap.listen("127.0.0.1:0");
    defer net.close($l);
    spawn { ldap.serveOn(fixture(), $l); };
    def a as string init net.address($l);
    def c as ldap.Conn init ldap.connect($a, PLAIN);
    def dn as string init dirauth.userDn($c, BASE, "alice");
    testing.assertTrue(dirauth.passwordOk($a, PLAIN, $dn, "s3cret"));
    testing.assertFalse(dirauth.passwordOk($a, PLAIN, $dn, "guess"));
    testing.assertEqual(dirauth.groupsOf($c, BASE, $dn), ["netops"]);
}

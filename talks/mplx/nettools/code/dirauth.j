import "ldap.j" as ldap;
import "transport.j" as transport;
use asn1;

export func userDn(c as ldap.Conn, base as string, uid as string) {
    def f as asn1.Value init ldap.allOf([
        ldap.equals("objectClass", "inetOrgPerson"),
        ldap.equals("uid", $uid)]);
    def hits as list of ldap.Entry init ldap.search($c, $base,
        ldap.SCOPE_SUB, $f, ["uid"]);
    if (len($hits) != 1) {
        return "";
    }
    return $hits[0].dn;
}

export func passwordOk(addr as string, sec as transport.Security,
    dn as string, password as string) {
    if ($dn == "" or $password == "") {
        return false;
    }
    def c as ldap.Conn init ldap.connect($addr, $sec);
    defer ldap.close($c);
    return ldap.bind($c, $dn, $password).code == ldap.SUCCESS;
}

export func groupsOf(c as ldap.Conn, base as string, dn as string) {
    def f as asn1.Value init ldap.allOf([
        ldap.equals("objectClass", "groupOfNames"),
        ldap.equals("member", $dn)]);
    def names as list of string;
    for (def g in ldap.search($c, $base, ldap.SCOPE_SUB, $f, ["cn"])) {
        $names[] = ldap.firstValue($g, "cn");
    }
    return $names;
}

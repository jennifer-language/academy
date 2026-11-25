---
theme: carbon
ratio: 16:9
transition: slide
---

# Network toolbox: SNMP, NTP, LDAP and IP addresses

![Jennifer](jennifer-logo.png)

Five bundled modules for the jobs a network admin scripts every week:
addresses and subnets, domain names, interface counters, clocks and
directories.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
This talk walks through five modules that ship with the interpreter: ipnet,
idna, snmp, ntp and ldap. Each gets a few slides with a small program, and at
the end they come together in a network health report. Every program on the
slides was run with the released 0.27.0 against real servers: net-snmp and
chrony in Alpine containers, an OpenLDAP™ container with its own certificate
authority, and one query to pool.ntp.org. Where 0.26.0 has a known bug that
the next release fixes, the notes say so.
-->

---

## Five modules, one toolbox

| Module | What it does | Needs |
| --- | --- | --- |
| `ipnet` | addresses, CIDR blocks, subnet maths, scopes | nothing: pure Jennifer |
| `idna` | international domain names to `xn--` and back | nothing: pure Jennifer |
| `snmp` | v1 / v2c manager, and a small agent | UDP (`net`) |
| `ntp` | one SNTP query: server time, offset, delay | UDP (`net`) |
| `ldap` | v3 client with StartTLS / LDAPS, and a small server | TCP and TLS (`net`) |

```jennifer
import "ipnet.j" as ipnet;   # bundled: no jvc, no vendor/
use io;

def a as ipnet.Address init ipnet.parseAddress("10.0.0.1");
io.printf("%v\n", ipnet.isPrivate($a));   # true
```

<!-- notes:
These are bundled modules, not decks: they live in the interpreter's module
directory and you import them by file name, with no jvc step. ipnet and idna
are plain Jennifer and run anywhere, even on the small TinyGo build. The other
three open sockets, so they need the default jennifer binary. None of them
needs a C library or an external tool: SNMP and LDAP are encoded with the asn1
library, byte by byte.
-->

---

## ipnet: addresses and networks

```jennifer excerpt
def net as ipnet.Network init ipnet.parse("198.51.100.77/26");
def a as ipnet.Address init ipnet.parseAddress("198.51.100.70");
io.printf("%s contains %s: %v\n", ipnet.networkString($net),
    ipnet.toString($a), ipnet.contains($net, $a));
def v6 as ipnet.Address init ipnet.parseAddress("2001:DB8:0:0::0:01");
io.printf("%s is IPv%d\n", ipnet.toString($v6), ipnet.version($v6));
def m as ipnet.Address init ipnet.parseAddress("::ffff:198.51.100.99");
io.printf("mapped: %s is IPv%d, inside: %v\n", ipnet.toString($m),
    ipnet.version($m), ipnet.contains($net, $m));
```

```text
198.51.100.64/26 contains 198.51.100.70: true
2001:db8::1 is IPv6
mapped: 198.51.100.99 is IPv4, inside: true
```

<!-- notes:
parse takes a CIDR block and zeroes the host bits, so the network prints as
.64/26 although we wrote .77. toString gives the canonical form; for IPv6 that
is RFC 5952, lower case and compressed, so two spellings of one address
compare equal. The last line matters for allow-lists: parseAddress folds an
IPv4-mapped IPv6 address down to plain IPv4, so ::ffff: cannot sneak a client
past a check written for IPv4 networks.
-->

---

## ipnet: subnet arithmetic

```jennifer excerpt
def n as ipnet.Network init ipnet.parse("198.51.100.64/26");
io.printf("mask %s, %d addresses, last host %s\n",
    ipnet.toString(ipnet.netmask($n)), ipnet.hostCount($n),
    ipnet.toString(ipnet.lastUsable($n)));
def subs as list of string;
for (def s in ipnet.split(ipnet.parse("2001:db8:10::/48"), 49)) {
    $subs[] = ipnet.networkString($s);
}
io.printf("split: %a\n", $subs);
```

```text
mask 255.255.255.192, 64 addresses, last host 198.51.100.126
split: [2001:db8:10::/49, 2001:db8:10:8000::/49]
```

<!-- notes:
firstUsable and lastUsable apply the usual conventions: IPv4 leaves out the
network and broadcast address, except in a /31 and /32. split cuts a block
into equal smaller ones, here a /48 into two /49s. aggregate goes the other
way and merges a list into the fewest covering blocks: 192.0.2.0/25 and
192.0.2.128/25 become 192.0.2.0/24, which is how you shorten a firewall list.
hosts lists every address but stops at 65536; walk bigger blocks with next.
-->

---

## ipnet: what kind of address is it?

```jennifer excerpt
for (def s in ["10.20.30.40", "fd00::1", "fe80::1", "::ffff:192.168.1.1",
    "100.64.0.1", "192.0.2.1", "ff02::1"]) {
    def a as ipnet.Address init ipnet.parseAddress($s);
    io.printf("%s|pad=20 %v\n", $s, ipnet.scope($a));
}
```

```text
10.20.30.40          ipnet.Scope.Private
fd00::1              ipnet.Scope.Private
fe80::1              ipnet.Scope.LinkLocal
::ffff:192.168.1.1   ipnet.Scope.Private
100.64.0.1           ipnet.Scope.Reserved
192.0.2.1            ipnet.Scope.Reserved
ff02::1              ipnet.Scope.Multicast
```

<!-- notes:
scope puts every address into exactly one of seven buckets, so a match
statement over the enum covers every case. The is functions, isPrivate,
isLoopback and the rest, are thin wrappers around it. Note the two Reserved
lines: carrier-grade NAT space and the documentation ranges are neither
private nor global. That is also why this slide shows no Global example: the
only addresses that classify as Global are real ones on the internet.
-->

---

## idna: international domain names

```jennifer excerpt
io.printf("%s\n", idna.toAscii("Bücher.Example"));
io.printf("%s\n", idna.toAscii("straße.example.org"));
io.printf("%s\n", idna.toUnicode("xn--mnchen-3ya.example"));
def long as string init "über-" + strings.replicate("x", 60);
try {
    io.printf("%s\n", idna.toAscii($long + ".example"));
} catch (e) {
    io.printf("[%s] %s\n", $e.kind, $e.message);
}
```

```text
xn--bcher-kva.example
xn--strae-oqa.example.org
münchen.example
[idna] idna: label too long for a 63-octet A-label
```

<!-- notes:
DNS, SMTP envelopes and URL hosts are ASCII only, so a name with an umlaut
travels as Punycode with an xn-- prefix. toAscii also lowercases. The sharp s
stays a sharp s and is encoded, as IDNA2008 requires, rather than becoming
"ss". The module checks the DNS lengths: a label over 63 octets is an error of
kind idna. It is Punycode plus lowercasing, not the full IDNA2008 tables, and
it does no script or bidi validation.
-->

---

## idna: why spoofing matters

```jennifer excerpt
func beyondLatin(host as string) {
    for (def ch in strings.chars(idna.toUnicode($host))) {
        if (convert.toCodepoint($ch) > 0x024F) { return true; }
    }
    return false;
}
def fake as string init convert.fromCodepoint(0x0430) + "pple.example";
io.printf("%v %s %v\n", $fake == "apple.example", idna.toAscii($fake),
    beyondLatin(idna.toAscii($fake)));
io.printf("%v\n", beyondLatin("xn--mnchen-3ya.example"));
```

```text
false xn--pple-43d.example true
false
```

<!-- notes:
U+0430 is the Cyrillic small a, which looks exactly like the Latin one, so the
fake name reads "apple" but is a different domain. The slide builds it with
fromCodepoint because the PDF font cannot show Cyrillic. Browsers show such
names in their xn-- form; a log viewer or a mail filter should do the same.
beyondLatin is a crude rule: anything past Latin Extended-B is flagged. In
0.26.0, toUnicode accepts some non-canonical xn-- labels and toAscii does not
refuse invisible characters; the next release rejects both.
-->

---

## SNMP: get and walk

```jennifer excerpt
def c as snmp.Client init snmp.clientWith("127.0.0.1:16161", "public",
    snmp.VERSION2C, 2000, 1);
def v as list of snmp.Varbind init snmp.get($c, ["1.3.6.1.2.1.1.3.0",
    "1.3.6.1.2.1.31.1.1.1.6.2"]);
io.printf("up %d ticks, %s [%s] %d\n", $v[0].number, $v[1].oid,
    $v[1].type, $v[1].number);
for (def vb in snmp.walk($c, "1.3.6.1.2.1.2.2.1.2")) {
    io.printf("%s = %s\n", $vb.oid, $vb.value);
}
```

```text
up 93657 ticks, 1.3.6.1.2.1.31.1.1.1.6.2 [counter64] 19062460
1.3.6.1.2.1.2.2.1.2.1 = lo
1.3.6.1.2.1.2.2.1.2.2 = eth0
```

<!-- notes:
The agent here is net-snmp's snmpd in a container, port 161 mapped to 16161 on
loopback. get asks for exact OIDs: sysUpTime in hundredths of a second, and
ifHCInOctets for interface 2, the bytes it received as a 64-bit counter. walk
follows GETNEXT through a subtree, here ifDescr, the interface names. Every
Varbind has the type, a string value and an int number. There is no MIB compiler, so OIDs
are numbers. In 0.26.0 a v1 walk throws at the end of the MIB instead of
stopping; use v2c, as here.
-->

---

## SNMP: bandwidth from two samples

```jennifer excerpt
func delta32(prev as int, cur as int) {
    if ($cur >= $prev) {
        return $cur - $prev;
    }
    return $cur + WRAP32 - $prev;
}
def a as list of snmp.Varbind init sample($c, "2");
time.sleep(time.fromSeconds(5));
def b as list of snmp.Varbind init sample($c, "2");
def secs as float init ($b[0].number - $a[0].number) / 100.0;
def bytesIn as int init delta32($a[1].number, $b[1].number);
```

```text
3171075 octets in 5.00 s: 5.07 Mbit/s
after a wrap: 1000
```

<!-- notes:
A counter tells you nothing; the difference of two readings does. sample gets
sysUpTime, ifInOctets and ifOutOctets in one request, so the time and the
counters come from the same moment, measured by the agent rather than by our
clock. A 32-bit counter wraps at 2 to the 32, which a busy gigabit port does
in about half a minute, so delta32 adds the wrap back; the last line checks it.
If uptime went down, the agent restarted and the sample is useless. In 0.26.0
unsigned values are not range-checked yet.
-->

---

## SNMP: a tiny agent for your own values

```jennifer excerpt
func snapshot() {
    return snmp.agent("lab-ro-7f3a", snmp.VERSION2C, [snmp.varbind(
        BASE + ".1.0", "gauge32", "", len(fs.list("spool")))]);
}
while (true) { # lint-disable: L105
    def stop as channel of bool init channel.make(1);
    def t as task of null init spawn {
        snmp.serveOn(snapshot(), $sock, $stop);
    };
    time.sleep(time.fromSeconds(10));
    channel.send($stop, true);
    task.wait($t);
}
```

<!-- notes:
An agent serves a fixed list of bindings, so this one rebuilds the list every
ten seconds: stop serveOn through its channel, then serve a fresh snapshot on
the same socket. BASE is under enterprise number 32473, which RFC 5612
reserves for examples. Every OID is writable to anyone who knows the
community, which travels in plain text, so bind the socket to loopback or a
management network and treat the agent as a read-out, never a control path.
A walk of the agent printed "1.3.6.1.4.1.32473.1.1.0 [gauge32] 3", and 4
after one more job file arrived and the next snapshot was served.
-->

---

## NTP: ask a server for the time

```jennifer
import "ntp.j" as ntp;
use io;
use time;

def r as ntp.Result init ntp.query("pool.ntp.org");
io.printf("server time %s\n", time.iso($r.serverTime));
io.printf("offset %d ms, delay %d ms\n", time.milliseconds($r.offset),
    time.milliseconds($r.delay));
```

```text
server time 2026-11-19T12:23:08.037108196Z
offset 126 ms, delay 282 ms
```

- **offset:** server minus local; positive means our clock is behind
- **delay:** the round trip, minus the server's own processing time
- A query measures; it never sets the clock (that is chrony's or ntpd's job)

<!-- notes:
query sends one 48-byte SNTP packet to port 123 and waits up to five seconds.
offset comes from four timestamps, two ours and two the server's, and assumes
the way there and back take equally long. That is why the error of the offset
can be up to half the delay: with 282 ms of round trip, the 126 ms offset here
is not proof of a wrong clock. Ask a nearby server, or several, before you
believe a number.
-->

---

## NTP: a drift check that warns

```jennifer excerpt
func checkNtp(server as string) {
    def r as ntp.Result init ntp.queryWith($server, 2000);
    def ms as int init time.milliseconds($r.offset);
    def rtt as int init time.milliseconds($r.delay);
    def level as string init "ok  ";
    if (math.abs($ms) >= WARN_MS) { $level = "WARN"; }
    if (math.abs($ms) >= FAIL_MS) { $level = "FAIL"; }
    return ["{$level} ntp {$server}: offset {$ms} ms, rtt {$rtt} ms"];
}
```

```text
ok   ntp 127.0.0.1:10123: offset 0 ms, rtt 3 ms
```

<!-- notes:
WARN_MS is 100 and FAIL_MS one second, sensible for log correlation; Kerberos
gives up at five minutes. The server here is a chrony container on loopback,
which shares the host's kernel clock, hence zero. A Kiss-o'-Death answer is an
NtpError with kissCode: RATE means poll less often, DENY or RSTR mean stop.
In 0.26.0 a Kiss-o'-Death sent with leap indicator 3 is misreported as an
unsynchronised server, and a stray datagram on the socket fails the query.
-->

---

## LDAP: never bind in plain text

```jennifer excerpt
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
```

```text
StartTLS, LDAPS, plain: [0, 0, 13]
```

<!-- notes:
A simple bind sends the password as it is, so only bind over StartTLS or
LDAPS. The 0.26.0 client binds over plain TCP without complaint; here the
OpenLDAP server refused with code 13, confidentialityRequired, but only after the password had crossed
the wire. Our lab uses its own CA. ldap.connect verifies against the system
roots, so for StartTLS the CA went into SSL_CERT_FILE; for LDAPS, a Conn built
from net.connectTLS takes the CA directly.
-->

---

## LDAP: users and groups

```jennifer excerpt
def who as string init "a*";
def f as asn1.Value init ldap.parseFilter("(uid="
    + ldap.escapeFilterValue($who) + ")");
def hits as list of ldap.Entry init ldap.search($c, BASE,
    ldap.SCOPE_SUB, $f, ["cn"]);
io.printf("%s: %d hits\n", ldap.escapeFilterValue($who), len($hits));
io.printf("groups: %a\n", dirauth.groupsOf($c, BASE, $alice));
```

```text
a\2a: 0 hits
groups: [netops, helpdesk]
```

<!-- notes:
The connection is bound as a read-only service account. A value typed by a
user must be escaped before it goes into a filter string: unescaped, "a*"
would match alice, and a crafted value could rewrite the whole filter. The
filter constructors, equals, present, allOf and the rest, take raw values and
need no escaping. groupsOf, a helper of ours, searches for a groupOfNames
whose member is alice's full DN, built with allOf and equals.
-->

---

## LDAP: check a password with bind

```jennifer excerpt
export func passwordOk(addr as string, sec as transport.Security,
    dn as string, password as string) {
    if ($dn == "" or $password == "") {
        return false;
    }
    def c as ldap.Conn init ldap.connect($addr, $sec);
    defer ldap.close($c);
    return ldap.bind($c, $dn, $password).code == ldap.SUCCESS;
}
```

```text
'alice-pw-2026': true
'guess': false
'': false
eve: ''
```

<!-- notes:
The way to check a password is to let the directory do it: find the user's DN
with the service account, then bind as that DN on a fresh connection. A wrong
password is not an exception; bind returns code 49 in the Result. The empty
password check comes first because an empty password is an unauthenticated
bind that many servers accept; the module refuses it too. userDn returns ""
unless exactly one entry matches, so eve gets nothing.
-->

---

## LDAP: large result sets

```jennifer excerpt
def hits as list of ldap.Entry init ldap.searchPaged($c, BASE,
    ldap.SCOPE_ONE, $f, [], 20);
io.printf("paged by 20: %d entries\n", len($hits));
try {
    $hits = ldap.search($c, BASE, ldap.SCOPE_ONE, $f, []);
} catch (e) {
    io.printf("%s\n", $e.message);
}
```

```text
paged by 20: 43 entries
ldap: search failed: code 4 ()
```

<!-- notes:
Servers cap how many entries one search returns. The lab's OpenLDAP allows 20
per search and 25 per page; Active Directory's default is 1000. Past the cap,
search fails with code 4, sizeLimitExceeded. searchPaged sends the paged
results control and collects page after page until the cookie is empty. A page
size above the server's own limit is refused with code 11, so pick a modest
one, a few hundred on a real directory.
-->

---

## LDAP: a directory server for your tests

```jennifer excerpt
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
```

```text
PASS testLoginAndGroups (59 ms)
```

<!-- notes:
fixture builds an in-memory directory with ldap.entry, ldap.group and a
PBKDF2 password from ldap.password. The server listens on a free loopback
port and stops when the listener closes, so the test needs no container and
runs in CI. Plain TCP is fine on loopback. Keep this server for tests: in
0.26.0 its search filters can probe userPassword, and it drops write requests
instead of answering them.
-->

---

## Errors, timeouts and limits

| What happened | `kind` | Real message |
| --- | --- | --- |
| no UDP answer, or a wrong community | `timeout` | snmp: no response from 127.0.0.1:16161 after 2 attempt(s) |
| CA not trusted | `net` | net.startTLS: tls: failed to verify certificate: ... |
| the agent refuses a SET | `snmp` | agent returned error-status 6 (noAccess) at index 1 |
| no such search base | `ldap` | ldap: search failed: code 32 () |
| a malformed address | `ipnet` | IPv4 octet out of range 0..255: 192.0.2.256 |

<!-- notes:
Each module throws a struct with a kind. SnmpError carries errorStatus and
statusName, LdapError the result code, NtpError the kissCode, so read those
fields once the kind matches; never parse the message. A wrong SNMP community
looks exactly like a dead host, because agents drop such requests silently.
ldap's 16 MiB message cap throws limit; ipnet's 65536 cap and ldap's filter
depth of 64 keep their module's kind.
-->

---

## Project: a network health report

```jennifer excerpt
func inMgmt(ip as string) {
    def a as ipnet.Address init ipnet.parseAddress($ip);
    for (def n in MGMT) {
        if (ipnet.contains(ipnet.parse($n), $a)) {
            return true;
        }
    }
    return false;
}
```

- `checkNtp`, `checkSnmp`, `checkLdap`: each returns report lines
- `checkSnmp` sends the community only where `inMgmt` says yes
- Guard and `spawn` as in [Homelab automation](https://academy.jennifer-lang.dev/talks/mplx/homelab/)

<!-- notes:
The report is about 150 lines and uses everything from the talk. inMgmt is the
ipnet part: the community string is a password in plain text, so checkSnmp
only sends it to addresses inside the management networks, MGMT. Then come two
samples, the restart check, delta32 and the interface's operational status. Each check runs in its own task behind a guard that turns
any error into a FAIL line, the same pattern as the homelab talk.
-->

---

## The report

```text
ok   ntp 127.0.0.1:10123: offset 0 ms, rtt 3 ms
ok   snmp 127.0.0.1:16161 if 2: up true, in 6.02, out 6.02 Mbit/s
FAIL snmp 127.0.0.1:16171 (timeout): snmp: no response from ...
WARN snmp 203.0.113.9:161: not a management address, skipped
ok   ldap localhost:10389: 43 people, netops 2
```

```sh
SNMP_COMMUNITY=... LDAP_BIND_DN=cn=reader,dc=example,dc=org \
  LDAP_PW=... SSL_CERT_FILE=lab-ca.pem jennifer run report.j
echo $?    # 1: one FAIL, one WARN
```

<!-- notes:
One real run against the lab. The second SNMP target is a switch that is
"down": nothing listens on that port, so the check times out after one retry
and the guard turns it into a FAIL line, shortened here. The address from
203.0.113.0/24 is outside the management networks and is never contacted.
Secrets come from the environment, as in a systemd EnvironmentFile. The exit
code makes the run fail for cron, systemd or CI.
-->

---

## Take-aways and read more

- **ipnet** for every address decision; parse, never compare strings
- **idna** before a name meets DNS, and show `xn--` where spoofing matters
- **SNMP** counters are differences over agent time; wrap at 2^32
- **NTP** offsets are only as good as half the delay
- **LDAP** only over StartTLS or LDAPS; escape filter values; bind to check
- Module docs: [ipnet](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/ipnet.md),
  [idna](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/idna.md),
  [snmp](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/snmp.md),
  [ntp](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/ntp.md),
  [ldap](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/ldap.md)
- More: [Errors](https://academy.jennifer-lang.dev/talks/mplx/errors/),
  [MikroTik™ as code](https://academy.jennifer-lang.dev/talks/mplx/mikrotik-iac/)

Based on Jennifer 0.27.0, November 2026.

<!-- notes:
Five modules, no external tools, and each is small enough to read: ldap.j is
the largest at about two thousand lines. If you script the network, start with
ipnet, because most network bugs are address bugs. The next release fixes the
0.26.0 issues mentioned in the notes; check the release notes before relying
on a workaround. The errors talk covers typed error structs in depth, and the
MikroTik talk shows configuration as code for routers.
-->

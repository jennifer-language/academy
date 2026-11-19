import "ipnet.j" as ipnet;
import "ldap.j" as ldap;
import "ntp.j" as ntp;
import "snmp.j" as snmp;
import "transport.j" as transport;
use io;
use math;
use os;
use strings;
use task;
use time;

def const MGMT as list of string init ["127.0.0.0/8",
    "198.51.100.0/24"];
def const WARN_MS as int init 100;
def const FAIL_MS as int init 1000;
def const WRAP32 as int init 4294967296;
def const UPTIME as string init "1.3.6.1.2.1.1.3.0";
def const OPER as string init "1.3.6.1.2.1.2.2.1.8.";
def const IN as string init "1.3.6.1.2.1.2.2.1.10.";
def const OUT as string init "1.3.6.1.2.1.2.2.1.16.";

def struct Check { kind as string, target as string, arg as string };

func delta32(prev as int, cur as int) {
    if ($cur >= $prev) {
        return $cur - $prev;
    }
    return $cur + WRAP32 - $prev;
}

func inMgmt(ip as string) {
    def a as ipnet.Address init ipnet.parseAddress($ip);
    for (def n in MGMT) {
        if (ipnet.contains(ipnet.parse($n), $a)) {
            return true;
        }
    }
    return false;
}

func checkNtp(server as string) {
    def r as ntp.Result init ntp.queryWith($server, 2000);
    def ms as int init time.milliseconds($r.offset);
    def rtt as int init time.milliseconds($r.delay);
    def level as string init "ok  ";
    if (math.abs($ms) >= WARN_MS) { $level = "WARN"; }
    if (math.abs($ms) >= FAIL_MS) { $level = "FAIL"; }
    return ["{$level} ntp {$server}: offset {$ms} ms, rtt {$rtt} ms"];
}

func sample(c as snmp.Client, i as string) {
    return snmp.get($c, [UPTIME, OPER + $i, IN + $i, OUT + $i]);
}

func mbit(octets as int, ticks as int) {
    def rate as float init $octets * 8 / ($ticks / 100.0) / 1000000.0;
    return io.sprintf("%f|prec=2", $rate);
}

func checkSnmp(addr as string, ifIndex as string) {
    if (not inMgmt(strings.split($addr, ":")[0])) {
        return ["WARN snmp {$addr}: not a management address, skipped"];
    }
    def c as snmp.Client init snmp.clientWith($addr,
        os.getEnv("SNMP_COMMUNITY"), snmp.VERSION2C, 1000, 1);
    def a as list of snmp.Varbind init sample($c, $ifIndex);
    time.sleep(time.fromSeconds(2));
    def b as list of snmp.Varbind init sample($c, $ifIndex);
    def ticks as int init $b[0].number - $a[0].number;
    if ($ticks <= 0) {
        return ["WARN snmp {$addr}: agent restarted, no rate"];
    }
    def inRate as string init mbit(delta32($a[2].number, $b[2].number),
        $ticks);
    def outRate as string init mbit(delta32($a[3].number, $b[3].number),
        $ticks);
    def up as bool init $b[1].number == 1;
    def line as string init "snmp {$addr} if {$ifIndex}: up {$up}, " +
        "in {$inRate}, out {$outRate} Mbit/s";
    if (not $up) {
        return ["WARN " + $line];
    }
    return ["ok   " + $line];
}

func checkLdap(addr as string, base as string) {
    def c as ldap.Conn init ldap.connect($addr,
        transport.Security.Starttls);
    defer ldap.close($c);
    def r as ldap.Result init ldap.bind($c, os.getEnv("LDAP_BIND_DN"),
        os.getEnv("LDAP_PW"));
    if ($r.code != ldap.SUCCESS) {
        return ["FAIL ldap {$addr}: bind refused, code {$r.code}"];
    }
    def people as list of ldap.Entry init ldap.searchPaged($c,
        "ou=people," + $base, ldap.SCOPE_ONE,
        ldap.equals("objectClass", "inetOrgPerson"), ["uid"], 20);
    def ops as list of ldap.Entry init ldap.search($c,
        "cn=netops,ou=groups," + $base, ldap.SCOPE_BASE,
        ldap.present("objectClass"), ["member"]);
    def n as int init len(ldap.values($ops[0], "member"));
    def p as int init len($people);
    def line as string init "ldap {$addr}: {$p} people, netops {$n}";
    if ($n == 0) {
        return ["WARN " + $line];
    }
    return ["ok   " + $line];
}

func guarded(ch as Check) {
    try {
        match ($ch.kind) {
            when "ntp" { return checkNtp($ch.target); }
            when "snmp" { return checkSnmp($ch.target, $ch.arg); }
            else { return checkLdap($ch.target, $ch.arg); }
        }
    } catch (e) {
        return ["FAIL {$ch.kind} {$ch.target} ({$e.kind}): " +
            $e.message];
    }
}

def checks as list of Check init [
    Check{kind: "ntp", target: "127.0.0.1:10123", arg: ""},
    Check{kind: "snmp", target: "127.0.0.1:16161", arg: "2"},
    Check{kind: "snmp", target: "127.0.0.1:16171", arg: "2"},
    Check{kind: "snmp", target: "203.0.113.9:161", arg: "1"},
    Check{kind: "ldap", target: "localhost:10389",
        arg: "dc=example,dc=org"}
];
def tasks as list of task of list of string;
for (def ch in $checks) {
    $tasks[] = spawn {
        return guarded($ch);
    };
}
def bad as int init 0;
for (def t in $tasks) {
    for (def line in task.wait($t)) {
        io.printf("%s\n", $line);
        if (not strings.startsWith($line, "ok")) {
            $bad = $bad + 1;
        }
    }
}
if ($bad > 0) {
    exit 1;
}

import "snmp.j" as snmp;
use io;
use time;

def const WRAP32 as int init 4294967296;
def const UPTIME as string init "1.3.6.1.2.1.1.3.0";
def const IN as string init "1.3.6.1.2.1.2.2.1.10.";
def const OUT as string init "1.3.6.1.2.1.2.2.1.16.";

func delta32(prev as int, cur as int) {
    if ($cur >= $prev) {
        return $cur - $prev;
    }
    return $cur + WRAP32 - $prev;
}

func sample(c as snmp.Client, i as string) {
    return snmp.get($c, [UPTIME, IN + $i, OUT + $i]);
}

def c as snmp.Client init snmp.clientWith("127.0.0.1:16161", "public",
    snmp.VERSION2C, 2000, 1);
def a as list of snmp.Varbind init sample($c, "2");
time.sleep(time.fromSeconds(5));
def b as list of snmp.Varbind init sample($c, "2");
def secs as float init ($b[0].number - $a[0].number) / 100.0;
def bytesIn as int init delta32($a[1].number, $b[1].number);
def mbit as float init $bytesIn * 8 / $secs / 1000000.0;
io.printf("%d octets in %f|prec=2 s: %f|prec=2 Mbit/s\n", $bytesIn,
    $secs, $mbit);
io.printf("after a wrap: %d\n", delta32(4294967000, 704));

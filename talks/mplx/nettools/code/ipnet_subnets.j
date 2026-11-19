import "ipnet.j" as ipnet;
use io;

def n as ipnet.Network init ipnet.parse("198.51.100.64/26");
io.printf("mask %s, %d addresses, last host %s\n",
    ipnet.toString(ipnet.netmask($n)), ipnet.hostCount($n),
    ipnet.toString(ipnet.lastUsable($n)));
def subs as list of string;
for (def s in ipnet.split(ipnet.parse("2001:db8:10::/48"), 49)) {
    $subs[] = ipnet.networkString($s);
}
io.printf("split: %a\n", $subs);

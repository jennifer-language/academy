import "ipnet.j" as ipnet;
use io;

def net as ipnet.Network init ipnet.parse("198.51.100.77/26");
def a as ipnet.Address init ipnet.parseAddress("198.51.100.70");
io.printf("%s contains %s: %v\n", ipnet.networkString($net),
    ipnet.toString($a), ipnet.contains($net, $a));
def v6 as ipnet.Address init ipnet.parseAddress("2001:DB8:0:0::0:01");
io.printf("%s is IPv%d\n", ipnet.toString($v6), ipnet.version($v6));
def m as ipnet.Address init ipnet.parseAddress("::ffff:198.51.100.99");
io.printf("mapped: %s is IPv%d, inside: %v\n", ipnet.toString($m),
    ipnet.version($m), ipnet.contains($net, $m));

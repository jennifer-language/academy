import "ipnet.j" as ipnet;   # bundled: no jvc, no vendor/
use io;

def a as ipnet.Address init ipnet.parseAddress("10.0.0.1");
io.printf("%v\n", ipnet.isPrivate($a));   # true

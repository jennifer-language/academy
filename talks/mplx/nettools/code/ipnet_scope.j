import "ipnet.j" as ipnet;
use io;

for (def s in ["10.20.30.40", "fd00::1", "fe80::1", "::ffff:192.168.1.1",
    "100.64.0.1", "192.0.2.1", "ff02::1"]) {
    def a as ipnet.Address init ipnet.parseAddress($s);
    io.printf("%s|pad=20 %v\n", $s, ipnet.scope($a));
}

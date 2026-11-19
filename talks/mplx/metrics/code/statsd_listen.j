# pragma-jennifer-version: >=0.26.0
# pragma-jennifer-capability: net

/**
 * A stand-in StatsD agent: print every datagram that arrives, as text.
 * @module listen
 */
use convert;
use io;
use net;

def sock as net.UDPSocket init net.listenUDP("127.0.0.1:8125");
while (true) { # lint-disable: L105
    def d as net.Datagram init net.recvFrom($sock, 2048);
    io.printf("%d bytes: %s\n", len($d.data), convert.stringFromBytes("utf-8", $d.data));
}

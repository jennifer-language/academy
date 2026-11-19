import "snmp.j" as snmp;
use channel;
use fs;
use net;
use task;
use time;

def const BASE as string init "1.3.6.1.4.1.32473.1";

func snapshot() {
    return snmp.agent("lab-ro-7f3a", snmp.VERSION2C, [snmp.varbind(
        BASE + ".1.0", "gauge32", "", len(fs.list("spool")))]);
}

def sock as net.UDPSocket init net.listenUDP("127.0.0.1:16170");
while (true) { # lint-disable: L105
    def stop as channel of bool init channel.make(1);
    def t as task of null init spawn {
        snmp.serveOn(snapshot(), $sock, $stop);
    };
    time.sleep(time.fromSeconds(10));
    channel.send($stop, true);
    task.wait($t);
}

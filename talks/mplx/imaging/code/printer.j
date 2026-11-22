use io;
use net;
use encoding;

# a stand-in for a printer's raw port: print one job and stop
def l as net.Listener init net.listen("127.0.0.1:9100");
def c as net.Conn init net.accept($l);
def job as bytes init net.readAll($c, 1000000, 5000);
net.close($c);
net.close($l);
io.printf("%d bytes:\n%s", len($job), encoding.decode("utf-8", $job));

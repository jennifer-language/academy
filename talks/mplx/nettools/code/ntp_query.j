import "ntp.j" as ntp;
use io;
use time;

def r as ntp.Result init ntp.query("pool.ntp.org");
io.printf("server time %s\n", time.iso($r.serverTime));
io.printf("offset %d ms, delay %d ms\n", time.milliseconds($r.offset),
    time.milliseconds($r.delay));

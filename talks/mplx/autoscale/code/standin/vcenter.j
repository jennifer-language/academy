# A stand-in for the few vCenter REST calls the autoscaler makes. VMs live
# in memory; a guest shutdown takes SHUTDOWN_MS before POWERED_OFF.
# Usage: jennifer run vcenter.j --listen 127.0.0.1:18443
use httpd;
use io;
use os;
use strings;
use convert;
use time;
use json;
use maps;
use regex;

def const SHUTDOWN_MS as int init 3000;
def const SESSION as string init "b00c-standin-session";

def struct Vm {
    id as string,
    name as string,
    power as string,
    offAt as int
};

def struct World {
    vms as map of string to Vm,
    next as int
};

func nowMs() {
    return time.unixMillis(time.now());
}

func send(req as httpd.Request, status as int, body as string) {
    httpd.setHeader($req, "Content-Type", "application/json");
    httpd.respond($req, $status, $body);
}

func settle(w as World) {
    for (def id in $w.vms) {
        def v as Vm init $w.vms[$id];
        if ($v.offAt > 0 and nowMs() >= $v.offAt) {
            $v.power = "POWERED_OFF";
            $v.offAt = 0;
            $w.vms[$id] = $v;
        }
    }
    return $w;
}

func listing(w as World) {
    def parts as list of string init [];
    for (def id in $w.vms) {
        def v as Vm init $w.vms[$id];
        $parts[] = '{"vm":"' + $id + '","name":"' + $v.name + '","power_state":"' + $v.power +
            '","cpu_count":2,"memory_size_MiB":2048}';
    }
    return "[" + strings.join($parts, ",") + "]";
}

func handle(w as World, req as httpd.Request) {
    def path as string init httpd.path($req);
    def m as string init httpd.method($req);
    def action as string init httpd.query($req, "action");
    io.printf("vcenter stand-in: %s %s %s\n", $m, $path, $action);
    if ($m == "POST" and $path == "/api/session") {
        send($req, 201, '"' + SESSION + '"');
        return $w;
    }
    if (httpd.header($req, "vmware-api-session-id") != SESSION) {
        send($req, 401, '{"error_type":"UNAUTHENTICATED","messages":[]}');
        return $w;
    }
    $w = settle($w);
    if ($path == "/api/vcenter/vm" and $m == "GET") {
        send($req, 200, listing($w));
        return $w;
    }
    if ($path == "/api/vcenter/vm" and $action == "clone") {
        def body as json.Value init json.decode(convert.stringFromBytes("utf-8", httpd.body($req)));
        def id as string init "vm-" + convert.toString($w.next);
        $w.next = $w.next + 1;
        def power as string init "POWERED_OFF";
        if (json.asBool($body, "/power_on")) {
            $power = "POWERED_ON";
        }
        $w.vms[$id] = Vm{id: $id, name: json.asString($body, "/name"), power: $power, offAt: 0};
        send($req, 200, '"' + $id + '"');
        return $w;
    }
    def g as regex.Match init regex.find('^/api/vcenter/vm/(vm-[0-9]+)(/.*)?$', $path);
    if ($g.start < 0 or not maps.has($w.vms, $g.groups[0])) {
        send($req, 404, '{"error_type":"NOT_FOUND","messages":[]}');
        return $w;
    }
    def id as string init $g.groups[0];
    def v as Vm init $w.vms[$id];
    match ($m + " " + $g.groups[1] + "?" + $action) {
        when "POST /power?start" {
            $v.power = "POWERED_ON";
            $w.vms[$id] = $v;
            send($req, 204, "");
        }
        when "POST /guest/power?shutdown" {
            $v.offAt = nowMs() + SHUTDOWN_MS;
            $w.vms[$id] = $v;
            send($req, 204, "");
        }
        when "DELETE ?" {
            $w.vms = maps.delete($w.vms, $id);
            send($req, 204, "");
        }
        else { send($req, 501, '{"error_type":"UNSUPPORTED","messages":[]}'); }
    }
    return $w;
}

func main() {
    def srv as httpd.Server init httpd.listen(os.flag("--listen"));
    def w as World init World{vms: {}, next: 200};
    $w.vms["vm-100"] = Vm{id: "vm-100", name: "worker-template", power: "POWERED_OFF", offAt: 0};
    $w.vms["vm-42"] = Vm{id: "vm-42", name: "exchange", power: "POWERED_ON", offAt: 0};
    while (true) { # lint-disable: L105
        $w = handle($w, httpd.accept($srv));
    }
}

main();

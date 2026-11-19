# A stand-in for the few Proxmox VE API calls the autoscaler makes. It
# keeps guests in memory: a clone appears stopped, start runs it, and a
# shutdown takes SHUTDOWN_MS before the guest reports stopped.
# Usage: jennifer run pve.j --listen 127.0.0.1:18006
use httpd;
use io;
use os;
use strings;
use convert;
use time;
import "uri.j" as uri;
use regex;
use maps;

def const SHUTDOWN_MS as int init 3000;
def const NODE as string init "pve1";

def struct Vm {
    vmid as int,
    name as string,
    status as string,
    template as bool,
    stopAt as int
};

def struct World {
    vms as map of int to Vm,
    tasks as int
};

func nowMs() {
    return time.unixMillis(time.now());
}

func reply(req as httpd.Request, status as int, data as string) {
    httpd.setHeader($req, "Content-Type", "application/json");
    httpd.respond($req, $status, '{"data":' + $data + '}');
}

func upid(n as int, kind as string, vmid as int) {
    return '"UPID:' + NODE + ':0000' + convert.toString(1000 + $n) + ':00000001:6740A0B0:' + $kind +
        ':' +
        convert.toString($vmid) + ':autoscale@pve!ctl:"';
}

func settle(w as World) {
    for (def id in $w.vms) {
        def v as Vm init $w.vms[$id];
        if ($v.stopAt > 0 and nowMs() >= $v.stopAt) {
            $v.status = "stopped";
            $v.stopAt = 0;
            $w.vms[$id] = $v;
        }
    }
    return $w;
}

func listing(w as World) {
    def parts as list of string init [];
    for (def id in $w.vms) {
        def v as Vm init $w.vms[$id];
        def tmpl as string init "0";
        if ($v.template) {
            $tmpl = "1";
        }
        $parts[] = '{"vmid":' + convert.toString($id) + ',"name":"' + $v.name + '","node":"' +
            NODE +
            '","type":"qemu","status":"' + $v.status + '","template":' + $tmpl + '}';
    }
    return "[" + strings.join($parts, ",") + "]";
}

func nextFree(w as World) {
    def id as int init 100;
    while (maps.has($w.vms, $id)) {
        $id = $id + 1;
    }
    return $id;
}

func handle(w as World, req as httpd.Request) {
    def path as string init httpd.path($req);
    def m as string init httpd.method($req);
    io.printf("pve stand-in: %s %s\n", $m, $path);
    if (not strings.startsWith(httpd.header($req, "Authorization"), "PVEAPIToken=")) {
        reply($req, 401, "null");
        return $w;
    }
    $w = settle($w);
    $w.tasks = $w.tasks + 1;
    if ($path == "/api2/json/cluster/resources") {
        reply($req, 200, listing($w));
        return $w;
    }
    if ($path == "/api2/json/cluster/nextid") {
        reply($req, 200, '"' + convert.toString(nextFree($w)) + '"');
        return $w;
    }
    if (strings.startsWith($path, "/api2/json/nodes/" + NODE + "/tasks/")) {
        reply($req, 200, '{"status":"stopped","exitstatus":"OK"}');
        return $w;
    }
    def g as regex.Match init regex.find('^/api2/json/nodes/pve1/qemu/([0-9]+)(/.*)?$', $path);
    if ($g.start < 0 or not maps.has($w.vms, convert.toInt($g.groups[0]))) {
        reply($req, 404, "null");
        return $w;
    }
    def id as int init convert.toInt($g.groups[0]);
    def action as string init $m + " " + $g.groups[1];
    def v as Vm init $w.vms[$id];
    match ($action) {
        when "POST /clone" {
            def form as map of string to string init uri.parseQuery(convert.stringFromBytes(
                "utf-8",
                httpd.body($req)));
            def newid as int init convert.toInt($form["newid"]);
            $w.vms[$newid] = Vm{
                vmid: $newid,
                name: $form["name"],
                status: "stopped",
                template: false,
                stopAt: 0
            };
            reply($req, 200, upid($w.tasks, "qmclone", $id));
        }
        when "POST /status/start" {
            $v.status = "running";
            $w.vms[$id] = $v;
            reply($req, 200, upid($w.tasks, "qmstart", $id));
        }
        when "POST /status/shutdown" {
            $v.stopAt = nowMs() + SHUTDOWN_MS;
            $w.vms[$id] = $v;
            reply($req, 200, upid($w.tasks, "qmshutdown", $id));
        }
        when "DELETE " {
            $w.vms = maps.delete($w.vms, $id);
            reply($req, 200, upid($w.tasks, "qmdestroy", $id));
        }
        else { reply($req, 501, "null"); }
    }
    return $w;
}

func main() {
    def srv as httpd.Server init httpd.listen(os.flag("--listen"));
    def w as World init World{vms: {}, tasks: 0};
    $w.vms[9000] = Vm{
        vmid: 9000,
        name: "worker-template",
        status: "stopped",
        template: true,
        stopAt: 0
    };
    $w.vms[100] = Vm{vmid: 100, name: "gitea", status: "running", template: false, stopAt: 0};
    while (true) { # lint-disable: L105
        $w = handle($w, httpd.accept($srv));
    }
}

main();

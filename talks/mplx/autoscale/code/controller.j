# The autoscaler: watch Resque's waiting counts, launch workers fast,
# drain them slowly. Usage: jennifer run controller.j docker|proxmox|vbox|vmware
import "resque.j" as resque;
import "redis.j" as redis;
import "transport.j" as transport;
import "log.j" as log;
import "./backend.j" as backend;
import "@deckyard/docker/" as docker;
import "@deckyard/proxmox/" as proxmox;
import "@deckyard/virtualbox/" as virtualbox;
import "@deckyard/vmware/" as vmware;
use io;
use os;
use time;
use convert;
use json;
use lists;
use maps;
use math;

def const PREFIX as string init "academy-scale-w-";
def const QUEUES as list of string init ["high", "thumbs"];
def const JOBS_PER_WORKER as int init 10;
def const MIN_WORKERS as int init 0;
def const MAX_WORKERS as int init 5;
def const MAX_LAUNCH_PER_TICK as int init 3;
def const LAUNCHES_PER_HOUR as int init 40;
def const TICK_MS as int init 2000;
def const GRACE_MS as int init 10000;
def const COOLDOWN_MS as int init 15000;
def const MAX_BACKOFF_MS as int init 60000;
def const HOLD_KEY as string init "autoscale:hold";

/** What the controller remembers between ticks. */
def struct State {
    lowSince as int,
    lastLaunch as int,
    launches as list of int,
    draining as map of string to int,
    failures as int,
    warm as int,
    started as int
};

def lg as log.Logger init log.toFile("logfmt", "info", "decisions.log");

func nowMs() {
    return time.unixMillis(time.now());
}

/** One line on the console, one record in decisions.log. */
func note(st as State, event as string, fields as map of string to string) {
    def secs as float init convert.toFloat(nowMs() - $st.started) / 1000.0;
    def line as string init io.sprintf("%f|prec=1|pad=5 s  %s", $secs, $event);
    for (def k in $fields) {
        $line = $line + " " + $k + "=" + $fields[$k];
    }
    io.printf("%s\n", $line);
    log.info($lg, $event, $fields);
}

/** How many workers the backlog asks for, within the bounds. */
func desired(waiting as int) {
    def want as int init ($waiting + JOBS_PER_WORKER - 1) // JOBS_PER_WORKER;
    return math.min(math.max($want, MIN_WORKERS), MAX_WORKERS);
}

/** Seconds the oldest job has waited: the producer stamps args[1]. */
func oldestAge(db as redis.Session) {
    def oldest as int init 0;
    for (def q in QUEUES) {
        def r as redis.Reply init redis.command($db, ["LINDEX", "resque:queue:" + $q, "0"]);
        if ($r.kind == "string") {
            def v as json.Value init json.decode($r.str);
            if (json.length($v, "/args") > 1) {
                def age as int init (nowMs() - convert.toInt(json.asString($v, "/args/1"))) // 1000;
                $oldest = math.max($oldest, $age);
            }
        }
    }
    return $oldest;
}

func waitingJobs(db as redis.Session) {
    def total as int init 0;
    for (def q in QUEUES) {
        $total = $total + resque.queueLength($db, $q);
    }
    return $total;
}

/** Launches in the last hour, the budget's measure. */
func recent(launches as list of int) {
    def out as list of int init [];
    for (def t in $launches) {
        if (nowMs() - $t < 3600000) {
            $out[] = $t;
        }
    }
    return $out;
}

func newName(db as redis.Session) {
    return PREFIX + convert.toString(redis.command($db, ["INCR", "autoscale:seq"]).num);
}

/** Remove stopped instances beyond the warm pool; forget drained ones. */
func reap(b as backend.Backend, st as State, all as list of backend.Instance) {
    def kept as int init 0;
    for (def i in $all) {
        if ($i.state != "stopped") {
            continue;
        }
        if (maps.has($st.draining, $i.name)) {
            def took as int init nowMs() - $st.draining[$i.name];
            $st.draining = maps.delete($st.draining, $i.name);
            note($st, "drained", {"name": $i.name, "took": convert.toString($took) + "ms"});
        }
        if ($kept < $st.warm) {
            $kept = $kept + 1;
            continue;
        }
        def said as string init backend.lastWords($b, $i);
        if ($said != "") {
            note($st, "said", {"name": $i.name, "last": "\"" + $said + "\""});
        }
        backend.remove($b, $i);
        note($st, "removed", {"name": $i.name});
    }
    return $st;
}

func scaleUp(
    b as backend.Backend,
    db as redis.Session,
    st as State,
    all as list of backend.Instance,
    n as int) {
    def warm as list of backend.Instance init lists.filter($all, isStopped);
    for (def k in 0..$n) {
        if ($k < len($warm) and $k < $st.warm) { # the ones reap kept
            backend.start($b, $warm[$k]);
            note($st, "started", {"name": $warm[$k].name});
        } else {
            def name as string init newName($db);
            backend.create($b, PREFIX, $name);
            note($st, "launched", {"name": $name});
        }
    }
}

func isUp(i as backend.Instance) {
    return $i.state != "stopped";
}

func isStopped(i as backend.Instance) {
    return $i.state == "stopped";
}

func scaleDown(b as backend.Backend, st as State, active as list of backend.Instance, n as int) {
    # the newest first: names sort by their sequence number
    for (def k in 0..$n) {
        def i as backend.Instance init $active[len($active) - 1 - $k];
        backend.drain($b, $i);
        $st.draining[$i.name] = nowMs();
        note($st, "drain", {"name": $i.name});
    }
    $st.lowSince = 0;
    return $st;
}

/** One look at the queues and the pool, and at most one decision. */
func tick(b as backend.Backend, db as redis.Session, st as State) { # lint-disable: L205
    def all as list of backend.Instance init backend.instances($b, PREFIX);
    $st = reap($b, $st, $all);
    def active as list of backend.Instance init [];
    for (def i in $all) {
        if ($i.state == "running" and not maps.has($st.draining, $i.name)) {
            $active[] = $i;
        }
    }
    def waiting as int init waitingJobs($db);
    def want as int init desired($waiting);
    def have as int init len($active);
    if (redis.command($db, ["EXISTS", HOLD_KEY]).num == 1) {
        note($st, "hold", {"waiting": convert.toString($waiting)});
        return $st;
    }
    if ($want > $have) {
        $st.lowSince = 0;
        $st.launches = recent($st.launches);
        def budget as int init LAUNCHES_PER_HOUR - len($st.launches);
        def room as int init MAX_WORKERS - len(lists.filter($all, isUp)); # draining ones count
        def n as int init math.min(
            math.min($want - $have, MAX_LAUNCH_PER_TICK),
            math.min($budget, $room));
        note(
            $st,
            "scale up",
            {
                "waiting": convert.toString($waiting),
                "oldest": convert.toString(oldestAge($db)) + "s",
                "have": convert.toString($have),
                "want": convert.toString($want),
                "launch": convert.toString($n)
            });
        if ($n > 0) {
            scaleUp($b, $db, $st, $all, $n);
            for (def k in 0..$n) {
                $st.launches[] = nowMs();
            }
            $st.lastLaunch = nowMs();
        }
        return $st;
    }
    if ($want < $have) {
        if ($st.lowSince == 0) {
            $st.lowSince = nowMs();
            note(
                $st,
                "below",
                {
                    "waiting": convert.toString($waiting),
                    "have": convert.toString($have),
                    "want": convert.toString($want)
                });
        }
        def low as int init nowMs() - $st.lowSince;
        def calm as int init nowMs() - $st.lastLaunch;
        if ($low >= GRACE_MS and $calm >= COOLDOWN_MS) {
            $st = scaleDown($b, $st, $active, $have - $want);
            return $st;
        }
        return $st;
    }
    $st.lowSince = 0;
    return $st;
}

func connectRedis() {
    return redis.connect(redis.Options{
        host: "127.0.0.1",
        port: convert.toInt(os.getEnv("REDIS_PORT")),
        security: transport.Security.None,
        user: "",
        password: "",
        db: 0
    });
}

func dockerBackend() {
    def c as docker.Client init docker.negotiate(docker.client(os.getEnv("DOCKER_URL")));
    return backend.Backend.Docker{
        c: $c,
        image: "ghcr.io/jennifer-language/jennifer:0.26.0",
        network: "academy-scale-net",
        bind: os.getEnv("WORKER_DIR"),
        env: {"REDIS_HOST": "academy-scale-redis", "REDIS_PORT": "6379"}
    };
}

func proxmoxBackend() {
    def c as proxmox.Client init proxmox.withToken(
        proxmox.client(os.getEnv("PVE_URL")),
        os.getEnv("PVE_TOKEN_ID"),
        os.getEnv("PVE_SECRET"));
    return backend.Backend.Proxmox{c: $c, template: 9000};
}

func vboxBackend() {
    def h as virtualbox.Host init virtualbox.open(virtualbox.withBinary(
        virtualbox.local(),
        os.getEnv("VBOXMANAGE")));
    return backend.Backend.Vbox{h: $h, template: "worker-template", snapshot: "base"};
}

func vmwareBackend() {
    def c as vmware.Client init vmware.login(
        vmware.client(os.getEnv("VCENTER_URL")),
        os.getEnv("VCENTER_USER"),
        os.getEnv("VCENTER_PASSWORD"));
    def place as vmware.Placement init vmware.Placement{
        folder: "group-v4",
        resourcePool: "resgroup-9",
        cluster: "",
        host: "",
        datastore: ""
    };
    return backend.Backend.Vmware{c: $c, template: "vm-100", placement: $place};
}

func choose(name as string) {
    match ($name) {
        when "docker" { return dockerBackend(); }
        when "proxmox" { return proxmoxBackend(); }
        when "vbox" { return vboxBackend(); }
        when "vmware" { return vmwareBackend(); }
        else { throw Error{kind: "value", message: "unknown backend " + $name}; }
    }
}

/** Worth another try: no answer (a generic kind), or the server's trouble. */
func transient(kind as string, status as int) {
    if ($kind == "net" or $kind == "timeout" or $kind == "closed") {
        return true;
    }
    return $status == 429 or $status >= 500;
}

func main() {
    os.catchSignal("term");
    os.catchSignal("int");
    def b as backend.Backend init choose(os.getEnv("BACKEND"));
    def db as redis.Session init connectRedis();
    def st as State init State{
        lowSince: 0,
        lastLaunch: 0,
        launches: [],
        draining: {},
        failures: 0,
        warm: 0,
        started: nowMs()
    };
    if (os.getEnv("WARM") != "") {
        $st.warm = convert.toInt(os.getEnv("WARM"));
    }
    # for the demo: stop once nothing runs or waits, after this many ms
    def idleAfter as int init 0;
    if (os.getEnv("STOP_IDLE_AFTER") != "") {
        $idleAfter = convert.toInt(os.getEnv("STOP_IDLE_AFTER")) * 1000;
    }
    note($st, "start", {"backend": backend.describe($b), "max": convert.toString(MAX_WORKERS)});
    for (def i in backend.instances($b, PREFIX)) {
        note($st, "adopt", {"name": $i.name, "state": $i.state});
    }
    def pause as int init TICK_MS;
    while (not (os.gotSignal("term") or os.gotSignal("int"))) {
        try {
            $st = tick($b, $db, $st);
            $st.failures = 0;
            $pause = TICK_MS;
        } catch (e) {
            def status as int init -1; # -1: no HTTP status at all
            match ($e.kind) {
                when "docker" {
                    def d as docker.DockerError init $e;
                    $status = $d.status;
                }
                when "proxmox" {
                    def p as proxmox.ProxmoxError init $e;
                    $status = $p.status;
                }
                when "vmware" {
                    def w as vmware.VmwareError init $e;
                    $status = $w.status;
                }
            }
            if (not transient($e.kind, $status)) {
                note($st, "fatal", {"kind": $e.kind, "error": $e.message});
                return 1;
            }
            $st.failures = $st.failures + 1;
            $pause = math.min($pause * 2, MAX_BACKOFF_MS);
            note(
                $st,
                "retry",
                {
                    "kind": $e.kind,
                    "status": convert.toString($status),
                    "in": convert.toString($pause) + "ms"
                });
        }
        if ($idleAfter > 0 and nowMs() - $st.started > $idleAfter and $st.failures == 0 and
            len(lists.filter(backend.instances($b, PREFIX), isUp)) == 0 and waitingJobs($db) == 0) {
            note($st, "idle, stopping", {});
            return 0;
        }
        time.sleep(time.fromMilliseconds($pause));
    }
    note($st, "signal, stopping", {"draining": convert.toString(len($st.draining))});
    return 0;
}

exit main();

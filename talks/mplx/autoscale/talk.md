---
theme: carbon
ratio: 16:9
transition: slide
---

# Dynamic workloads: autoscaling Resque workers with Jennifer

![Jennifer](jennifer-logo.png)

A controller that watches a Resque queue, launches workers on Docker™,
VirtualBox™, Proxmox™ or VMware™ when the backlog grows, and drains them
when it is gone.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
This talk builds one program of about six hundred lines: an autoscaler for
Resque workers. It reads the waiting counts, decides how many workers there
should be, and starts or drains them through four Deckyard decks. Resque
itself, enqueue and the worker loop, is covered in the queues talk, so here we
only use it. The Docker run on these slides is real: Redis™ 7 and worker
containers of the official 0.26.0 image on this machine. VirtualBox, Proxmox
and VMware ran against small local stand-ins, and every slide that shows
their output says so. Credentials are placeholders.
-->

---

## The problem: bursty load, idle cost

| | Fixed pool of 5 | Fixed pool of 1 | Autoscaled 0 to 5 |
| --- | --- | --- | --- |
| 60 jobs of 1.5 s arrive | done in about 20 s | done in 90 s | about 20 s, after a 1 s start |
| Quiet hours | 5 idle workers | 1 idle worker | nothing runs |
| Cost | the peak, all day | the average, slow at peaks | roughly the work done |

- Workers are cheap as containers, expensive as VMs: minutes to boot
- Scaling is a loop: **measure, decide, act**, every couple of seconds
- Resque basics: [the queues talk](https://academy.jennifer-lang.dev/talks/mplx/queues/)

<!-- notes:
Background jobs rarely arrive evenly. An import, a newsletter or a batch of
uploads puts sixty jobs on the queue at once, and then nothing happens for an
hour. A pool sized for the peak sits idle most of the day; a pool sized for
the average leaves the burst waiting. An autoscaler sits between the two. The
numbers in the first row are from the real run at the end of this talk. The
queues talk explains enqueue, reserve and the worker loop, which we take as
known here.
-->

---

## The pieces

| Piece | Version | Used for |
| --- | --- | --- |
| `resque.j` + `redis.j` (bundled) | 0.27.0 | queue lengths, the worker loop |
| `@deckyard/docker` | 0.2.0 | containers, by label |
| `@deckyard/virtualbox` | 0.1.0 | `VBoxManage`: linked clones, ACPI |
| `@deckyard/proxmox` | 0.2.0 | API token, clone, start, shutdown |
| `@deckyard/vmware` | 0.3.0 | vCenter™ REST: clone, guest shutdown |
| `log.j` (bundled) | 0.27.0 | one logfmt record per decision |

```sh
jvc add @deckyard/docker      # ... and proxmox, virtualbox, vmware
jvc install                   # copies their src/ into vendor/
```

<!-- notes:
Everything is either bundled with the interpreter or a community deck from
Deckyard. The controller imports all four decks, but uses only the one the
configuration picks. VirtualBox also has a second deck, virtualboxws, for its
SOAP web service; this talk uses the VBoxManage one, which needs nothing but
the command on the host. The docker and proxmox and vmware decks need the net
capability, virtualbox needs exec, so this is a program for the default
jennifer binary, not jennifer-tiny.
-->

---

## Measuring demand

```jennifer excerpt
func waitingJobs(db as redis.Session) {
    def total as int init 0;
    for (def q in QUEUES) {   # ["high", "thumbs"]
        $total = $total + resque.queueLength($db, $q);
    }
    return $total;
}
```

- `queueLength` is one `LLEN`: cheap enough for every tick
- Resque keeps **no timestamps** and the module **no worker registry**
- The age of the oldest job only exists if the producer stamps it

<!-- notes:
The obvious signal is how many jobs wait, summed over the queues the workers
serve. resque.size would sum every registered queue, including ones our
workers never touch, so we ask per queue. What Resque does not give us: the
job envelope is just class and args, with no enqueue time, and this module
does not register workers in Redis the way Ruby's Resque does. So jobs per
worker comes from the backend's own list of instances, and age needs help
from the producer, next slide.
-->

---

## The oldest job's age, by convention

```jennifer excerpt
# producer: args[1] is the enqueue time in Unix ms
def stamp as string init convert.toString(time.unixMillis(time.now()));
resque.enqueue($db, $queue, "Thumbnail", ["photo-{$i}.jpg", $stamp]);
# controller: look at the head of the list without popping it
def r as redis.Reply init redis.command($db,
    ["LINDEX", "resque:queue:" + $q, "0"]);
if ($r.kind == "string") {
    def v as json.Value init json.decode($r.str);
    def age as int init (nowMs() -
        convert.toInt(json.asString($v, "/args/1"))) // 1000;
}
```

```text
4.0 s  scale up waiting=60 oldest=1s have=0 want=5 launch=3
```

<!-- notes:
Waiting count alone cannot tell a queue that is long but moving from one that
is short but stuck. The age of the oldest job can. Since the envelope has no
time, our producer puts the enqueue time into the second argument, and the
controller peeks at the first element of each list with LINDEX, which reads
without taking the job. That relies on the documented Redis layout of the
module, resque:queue:NAME. The controller here only logs the age; a stricter
one could also scale up when the age passes a limit.
-->

---

## The rule: how many workers?

```jennifer excerpt
func desired(waiting as int) {
    def want as int init
        ($waiting + JOBS_PER_WORKER - 1) // JOBS_PER_WORKER;
    return math.min(math.max($want, MIN_WORKERS), MAX_WORKERS);
}
```

| waiting | 0 | 1 | 10 | 11 | 39 | 60 |
| --- | --- | --- | --- | --- | --- | --- |
| desired (10 per worker, 0 to 5) | 0 | 1 | 1 | 2 | 4 | 5 |

- `//` is integer division: `(w + n - 1) // n` is the ceiling
- `MIN_WORKERS` above 0 keeps a worker warm for the first job

<!-- notes:
desired is clamp of ceiling of waiting divided by jobs per worker, between a
minimum and a maximum. Jennifer's slash is true division and returns a float,
so the ceiling is written with double slash on integers. JOBS_PER_WORKER is
the backlog one worker should own: with jobs of 1.5 seconds, ten jobs is
fifteen seconds of work. Sixty waiting jobs would want six workers; the
maximum of five caps it. A minimum of zero means a cold start for the first
job after a quiet hour.
-->

---

## Up fast, down slowly

```jennifer excerpt
if ($want > $have) {                  # up at once, a few per tick
    $st.lowSince = 0;
    def n as int init math.min(math.min($want - $have,
        MAX_LAUNCH_PER_TICK), math.min($budget, $room));
    ...
}
if ($want < $have) {                  # down only after a while
    if ($st.lowSince == 0) { $st.lowSince = nowMs(); }
    def low as int init nowMs() - $st.lowSince;
    def calm as int init nowMs() - $st.lastLaunch;
    if ($low >= GRACE_MS and $calm >= COOLDOWN_MS) { ... }
}
```

<!-- notes:
Scaling up is cheap to get wrong, scaling down is not: a worker stopped too
early must be started again a minute later, which for a VM means another
boot. So up happens on the next tick, three launches at most per tick, and
down only when the demand has stayed below the pool for the whole grace
period of ten seconds and the last launch is at least fifteen seconds old.
Any tick with want equal to or above have resets the low streak: that is the
hysteresis that stops the pool from flapping around a boundary.
-->

---

## The worker drains itself

```jennifer excerpt
os.catchSignal("term");
while (true) {
    if (os.gotSignal("term")) { return 0; }   # only between jobs
    def job as resque.Job init
        resque.reserveBlocking($db, QUEUES, POLL);
    if ($job.class == "") {
        $idle = $idle + POLL;
        if ($idle >= IDLE_LIMIT) { return 0; }   # 30 s without work
        continue;
    }
    $idle = 0;
    ...   # perform, or resque.fail; both exits print a last line
}
```

<!-- notes:
This is the worker inside every container and VM. os.catchSignal turns
SIGTERM into a flag that the loop polls at a safe point, between two jobs,
so a stop request never interrupts a job. reserveBlocking waits at most two
seconds, which bounds how long a drain takes when the queue is empty. The
second exit is the safety net: after thirty seconds without a job the worker
leaves on its own, so a pool whose controller died still shrinks. The loop
ends only by return, so lint has nothing to say about while true.
-->

---

## Never kill a busy worker

- `reserve` is `LPOP`: a job taken by a killed worker is **lost**
- So the controller never kills; it asks, and the worker decides when

| Backend | Drain request | The worker sees |
| --- | --- | --- |
| Docker | `killContainer(c, id, "SIGTERM")` | SIGTERM, as PID 1 |
| VirtualBox | `acpiShutdown(h, vm)` | systemd stops the service: SIGTERM |
| Proxmox | `shutdown(c, g, 0)` | ACPI, then the same |
| VMware | `shutdownGuest(c, vm)` | VMware Tools shutdown, the same |

- A stopped instance is removed on a later tick: **drain, then reap**

<!-- notes:
Resque gives at most once delivery: reserve pops the job from Redis, and if
the process dies while working on it, the job is gone. That makes the stop
the dangerous half of autoscaling. Every backend has a polite stop: a signal
for a container, the power button for a VM, which a systemd unit turns into
SIGTERM for the worker service. In the guest, give the unit a
TimeoutStopSec longer than your longest job. killContainer with SIGTERM
returns at once, unlike stopContainer, which waits; the controller keeps
ticking.
-->

---

## One interface, four backends

```jennifer excerpt
export def enum Backend {
    Docker {
        c as docker.Client, image as string, network as string,
        bind as string, env as map of string to string
    },
    Proxmox { c as proxmox.Client, template as int },
    Vbox { h as virtualbox.Host, template as string,
        snapshot as string },
    Vmware { c as vmware.Client, template as string,
        placement as vmware.Placement }
};
export def struct Instance {
    id as string, name as string, state as string };
```

<!-- notes:
Jennifer has no interfaces, and a func value carries no state, there are no
closures. So the shape is data plus dispatch: an enum whose variants carry
each backend's client and settings, and one function per operation that
matches on the variant. Instance is the common view of a container or a VM,
with the state normalised to running, stopped or other. Adding a fifth
backend is one variant and one arm in each backend function, and the match
must be exhaustive, so the interpreter tells you which arm is missing.
-->

---

## Dispatch with match

```jennifer excerpt
export func drain(b as Backend, inst as Instance) {
    match ($b) {
        when Docker(d) {
            docker.killContainer($d.c, $inst.id, "SIGTERM"); }
        when Proxmox(p) {
            proxmox.shutdown($p.c, pveGuest($p.c, $inst.id), 0); }
        when Vbox(v) { virtualbox.acpiShutdown($v.h, $inst.id); }
        when Vmware(w) { vmware.shutdownGuest($w.c, $inst.id); }
    }
}
```

- `instances`, `create`, `start`, `drain`, `remove`: one `match` each
- A `when` arm binds the variant's payload: `$d.c`, `$p.template`

<!-- notes:
Each when arm binds the variant's payload, here d, p, v or w, and calls its
deck. The controller only ever calls backend.instances, create, start, drain,
remove, lastWords and describe, and never imports a deck function itself except to read
error fields. pveGuest is a one-line helper: the Proxmox deck works on Guest
values, so it looks the guest up by its vmid. Behind create are
createContainer and startContainer, linkedClone and start, linkedClone,
waitTask and start, or cloneVm; behind remove removeContainer, delete,
destroy and deleteVm. The next slides show each backend in turn.
-->

---

## Docker: labels find our own containers

```jennifer excerpt
def spec as docker.ContainerSpec init docker.containerSpec($d.image);
$spec = docker.withCmd($spec, ["run", "/app/worker.j"]);
$spec = docker.withEnv($spec, $env);   # REDIS_HOST, WORKER_NAME
$spec = docker.withLabels($spec, {POOL_LABEL: $prefix});
$spec = docker.withBind($spec, $d.bind, "/app", true);
$spec = docker.withNetworkMode($spec, $d.network);
docker.startContainer($d.c, docker.createContainer($d.c, $name, $spec));
# listing: the label filter, then the name prefix as well
docker.containers($c, true, ["label=autoscale.pool=" + $prefix]);
```

```text
academy-scale-w-1   Up 5 seconds    academy-scale-w-
academy-scale-w-manual   Up 10 seconds
```

<!-- notes:
The worker image is the official ghcr.io/jennifer-language/jennifer:0.26.0,
with worker.j mounted read-only. The label autoscale.pool says which
controller owns a container; the list asks the daemon with a label filter and
then also checks the name prefix. The container academy-scale-w-manual was
started by hand with the same prefix but without the label, and the
controller never touched it. The deck does not reach the Unix socket yet, so
a socat container exposed it on 127.0.0.1 only.
-->

---

## VirtualBox: linked clones from a snapshot

```jennifer excerpt
def h as virtualbox.Host init virtualbox.open(
    virtualbox.withBinary(virtualbox.local(), os.getEnv("VBOXMANAGE")));
virtualbox.linkedClone($v.h, $v.template, $v.snapshot, $name);
virtualbox.start($v.h, $name);           # headless
virtualbox.acpiShutdown($v.h, $inst.id); # drain
virtualbox.delete($v.h, $inst.id);       # reap
```

```text
VBoxManage clonevm worker-template --snapshot base --options link
  --name academy-scale-w-1 --register
VBoxManage startvm academy-scale-w-1 --type headless
VBoxManage controlvm 00000000-0000-4000-8000-000000000003 acpipowerbutton
VBoxManage unregistervm 00000000-0000-4000-8000-000000000001 --delete
```

<!-- notes:
Output from a stand-in: a shell script that answers like VBoxManage and keeps
its machines as files, the same technique the deck's own tests use. The
command lines are exactly what the deck ran. A linked clone of a snapshot
shares the template's disk and takes seconds instead of a full copy. The deck
runs VBoxManage locally, or over ssh with virtualbox.remote. In release 0.1.0
a failure is a plain Error of kind virtualbox, and errorCode reads the
VBOX_E code from it.
-->

---

## Proxmox: an API token, a clone task

```jennifer excerpt
def c as proxmox.Client init proxmox.withToken(
    proxmox.client(os.getEnv("PVE_URL")),
    os.getEnv("PVE_TOKEN_ID"), os.getEnv("PVE_SECRET"));
def id as int init proxmox.nextId($p.c);
def upid as string init proxmox.linkedClone($p.c,
    proxmox.guest($p.c, $p.template), $id, $name);
def t as proxmox.Task init
    proxmox.waitTask($p.c, $upid, CLONE_TIMEOUT_MS);
if ($t.exitStatus != "OK") { throw Error{kind: "scale", ...}; }
proxmox.start($p.c, proxmox.guest($p.c, $id));
```

```text
POST /api2/json/nodes/pve1/qemu/9000/clone
GET  /api2/json/nodes/pve1/tasks/UPID:...:qmclone:9000:.../status
POST /api2/json/nodes/pve1/qemu/101/status/start
```

<!-- notes:
Output from a stand-in: a Jennifer httpd server that keeps guests in memory
and answers the calls the deck makes, logged on the right. A token with
privilege separation needs only what cloning and power control take, such
as VM.Clone, VM.Allocate and VM.PowerMgmt. Clone and start return a task id, a UPID; waitTask polls
until the clone has finished, because starting a half-copied guest fails.
Start and shutdown are not waited for: the next ticks see the status change.
nextId can race with another client, so run one controller per pool.
-->

---

## VMware: boot time and the warm pool

```jennifer excerpt
vmware.cloneVm($w.c, $w.template, $name, $w.placement, true);
# WARM=1: reap keeps one stopped clone, scale-up starts it first
if ($k < len($warm) and $k < $st.warm) {
    backend.start($b, $warm[$k]);   # vmware.powerOn
}
```

```text
 20.2 s  drained name=academy-scale-w-1 took=4082ms
 20.2 s  drained name=academy-scale-w-2 took=4085ms
 20.2 s  removed name=academy-scale-w-2
 28.2 s  scale up waiting=5 oldest=0s have=0 want=1 launch=1
 28.2 s  started name=academy-scale-w-1
```

- Cold: clone + boot + service, minutes. Warm: boot only. Hot: `MIN_WORKERS`

<!-- notes:
Output from a stand-in vCenter in Jennifer, so the times say nothing about
real vSphere™. A real VM clone takes tens of seconds to minutes, then the
guest boots. Two knobs help: a warm pool of stopped clones that only need to
boot, set with WARM, and a minimum of running idle workers, which costs
memory but answers at once. The warm one, w-1, was kept stopped and started
again for the second burst instead of a new clone. vmware.vms with the zero
VmFilter lists every VM; the prefix picks ours.
-->

---

## Reconciliation after a restart

```text
--- t=12 s: kill -9 controller A
--- t=15 s: controller B starts
  0.0 s  start backend=docker ghcr.io/jennifer-language/jennifer:0.26.0
  0.0 s  adopt name=academy-scale-w-5 state=running
  ...
  0.0 s  adopt name=academy-scale-w-1 state=running
  0.0 s  below waiting=29 have=5 want=3
```

- No state file: the backend's list **is** the state (label or prefix)
- What is lost is only memory: who is draining, the launch budget
- Never touch others: `academy-scale-w-manual` had no label

<!-- notes:
Controller A was killed with SIGKILL in the middle of the burst; the five
workers did not care and kept working. Controller B started three seconds
later, listed the pool and simply continued from there. Its first decision
was that 29 waiting jobs need only three workers. Keeping no state of your
own means nothing to corrupt. The memory that is lost is small: a worker
that was draining is counted as running again, which at worst means it gets
a second SIGTERM.
-->

---

## When the controller stays dead

```text
--- t=6 s: kill -9 controller A
--- t=50 s: docker ps
academy-scale-w-3   Exited (0) 1 second ago
...
--- t=51 s: controller B starts
  0.0 s  adopt name=academy-scale-w-3 state=stopped
  0.1 s  said name=academy-scale-w-3 last="academy-scale-w-3:
         idle 30 s, exit after 10 jobs"
  0.1 s  removed name=academy-scale-w-3
```

- The workers' idle timeout shrinks the pool **without** a controller
- `lastWords`: `docker.logs(c, id, ["tail=1"])` before the removal

<!-- notes:
A second real run: a burst of thirty jobs, three workers, and the controller
killed after six seconds with nobody to restart it. The workers finished the
thirty jobs, ten each, waited thirty seconds and exited with code zero. When
controller B started at fifty-one seconds, it adopted the three stopped
containers, read the last line of each log and removed them. Without the
idle timeout, those workers would have run until someone noticed. For VMs the
same exit should power the guest off, for example with systemd.
-->

---

## Limits and safety

```jennifer excerpt
if (redis.command($db, ["EXISTS", HOLD_KEY]).num == 1) {
    note($st, "hold", {"waiting": convert.toString($waiting)});
    return $st;                         # the kill switch
}
$st.launches = recent($st.launches);    # launches in the last hour
def budget as int init LAUNCHES_PER_HOUR - len($st.launches);
def room as int init MAX_WORKERS - len(lists.filter($all, isUp));
```

- `MAX_WORKERS` counts draining instances too: they still cost
- `MAX_LAUNCH_PER_TICK` 3, `LAUNCHES_PER_HOUR` 40: a loop bug stays small
- `redis-cli SET autoscale:hold 1` freezes the pool, `DEL` releases it

<!-- notes:
An autoscaler is a program that spends money in a loop, so it needs brakes
that do not depend on its own logic being right. The maximum covers every
instance that is not stopped, including draining ones, because a VM shutting
down still holds its host's memory. The launch rate and the hourly budget
bound what a bug can do. The hold key is a kill switch any operator can set
without touching the controller: while it exists, nothing is launched or
drained.
-->

---

## When the backend API fails

| Case (from one test run) | Kind | Status |
| --- | --- | --- |
| docker: image missing | `docker` | 404 |
| docker: API unreachable | `net` | - |
| proxmox: no such template | `proxmox` | 0 (a local check) |
| proxmox: no token | `proxmox` | 401 |
| vmware: no such VM | `vmware` | 404 |
| vmware: session expired | `vmware` | 401 |
| virtualbox: no such VM | `virtualbox` | `VBOX_E_OBJECT_NOT_FOUND` |

- Each deck throws one struct: `DockerError`, `ProxmoxError`, `VmwareError`

<!-- notes:
Docker rows are from the real daemon; the Proxmox, VMware and VirtualBox rows
are from the stand-ins, which answer the way the real APIs document. Status 0
on a ProxmoxError means no HTTP status was read, here because the deck's own
guest lookup found nothing, so 0 is not a reason to retry. A network failure
is never a deck error: it is kind net, the NetError of the http module. For
an expired vCenter session, vmware.ensureSession logs in again.
-->

---

## Retry what is transient, stop on the rest

```jennifer excerpt
} catch (e) {
    def status as int init -1;   # -1: no HTTP status at all
    match ($e.kind) {
        when "docker" { def d as docker.DockerError init $e; ... }
        ...   # $status = $d.status; ProxmoxError, VmwareError alike
    }
    if (not transient($e.kind, $status)) { ... return 1; }
    $pause = math.min($pause * 2, MAX_BACKOFF_MS);
}
```

```text
  6.1 s  retry kind=net status=-1 in=4000ms
 10.1 s  retry kind=net status=-1 in=8000ms
```

<!-- notes:
transient is true for the generic kinds net, timeout and closed, and for HTTP
429 or 5xx. A 401 or a missing template does not heal by waiting, so the
controller logs it and exits; the workers then drain themselves. The output
is real: the socat proxy to the Docker API was stopped for seven seconds,
the tick doubled its pause, and once the proxy was back the controller went
on with the drain it had postponed. Assigning the caught value to the deck's
struct type gives typed fields; never parse a status out of a message.
-->

---

## Observability: log every decision

```jennifer excerpt
def lg as log.Logger init log.toFile("logfmt", "info", "decisions.log");
log.info($lg, $event, $fields);   # inside note(), next to the console
```

```text
time=2026-11-19T14:13:57.031Z level=info msg="scale up" waiting=60
  oldest=1s have=0 want=5 launch=3
time=2026-11-19T14:14:13.328Z level=info msg=retry kind=net
  status=-1 in=4000ms
```

- Log the inputs with the decision: waiting, oldest, have, want
- Export gauges too: [the metrics talk](https://academy.jennifer-lang.dev/talks/mplx/metrics/)

<!-- notes:
Every decision goes to the console as a short line and to decisions.log as a
logfmt record; the timestamps here are shortened to fit the slide. When
someone asks why there were five VMs at three in the morning, the answer is
one grep away, because each record carries the numbers the decision was made
from. For dashboards, export waiting, have, want and the launch count as
gauges and counters to Prometheus™, StatsD or InfluxDB™, as the metrics talk
shows; alert on the hold key and on fatal exits.
-->

---

## A full run on Docker, part 1

```text
--- t=3 s: burst of 60
  4.0 s  scale up waiting=60 oldest=1s have=0 want=5 launch=3
  4.3 s  launched name=academy-scale-w-1
  4.5 s  launched name=academy-scale-w-2
  4.9 s  launched name=academy-scale-w-3
  6.9 s  scale up waiting=54 oldest=4s have=3 want=5 launch=2
  7.2 s  launched name=academy-scale-w-4
  7.4 s  launched name=academy-scale-w-5
--- t=12 s: kill -9 controller A
--- t=15 s: controller B starts, adopts 5, waiting=29 want=3
--- t=20 s: Docker API proxy stopped, t=27 s: started
```

<!-- notes:
The whole run, from run.sh in the talk's code folder. Sixty jobs of 1.5
seconds each, 90 seconds of work for one worker. The first three containers
started within a second, two more on the next tick: the per-tick limit of
three. Each launch is a create and a start through the Docker API, about 0.3
seconds. Then the controller was killed, a second one took over, and the
Docker API went away for seven seconds, all while the workers kept draining
the queue.
-->

---

## A full run on Docker, part 2

```text
 18.2 s  drain name=academy-scale-w-1      (... w-2 to w-5)
 20.3 s  said name=academy-scale-w-5 last="academy-scale-w-5:
         SIGTERM, drained after 11 jobs"
 20.6 s  removed name=academy-scale-w-1
--- t=50 s: burst of 8 on high
 36.7 s  scale up waiting=8 oldest=1s have=0 want=1 launch=1
 49.9 s  below waiting=0 have=1 want=0
 60.1 s  drain name=academy-scale-w-6
 64.2 s  said ... "academy-scale-w-6: SIGTERM, drained after 8 jobs"
 64.2 s  idle, stopping
```

- 60 jobs: 11 + 11 + 12 + 13 + 13, none lost; `docker ps -a`: nothing left

<!-- notes:
Times now count from controller B's start, fifteen seconds after the burst
began. By eighteen seconds the queue was empty, the grace period had passed,
and all five workers got SIGTERM; each finished its job and exited within
about two seconds. The job counts add up to sixty. The second burst of eight
needed one worker, which ran for twelve seconds and was drained ten seconds
after the queue emptied. Afterwards no academy-scale container was left
behind.
-->

---

## Checklist

- Measure per queue; stamp jobs if age matters
- `desired = clamp(ceil(waiting / perWorker), min, max)`
- Up within a tick, down after a grace period and a cooldown
- Drain, never kill: SIGTERM or ACPI, polled between jobs
- Workers time out on their own; the controller is optional
- Own instances by label or prefix; the backend's list is the state
- Caps, a launch budget, a hold key; retry only transient errors

Code: `code/` beside this talk. Decks:
[docker](https://registry.jennifer-lang.dev/deck/deckyard/docker),
[virtualbox](https://registry.jennifer-lang.dev/deck/deckyard/virtualbox),
[proxmox](https://registry.jennifer-lang.dev/deck/deckyard/proxmox),
[vmware](https://registry.jennifer-lang.dev/deck/deckyard/vmware)

<!-- notes:
Most of the controller is policy: when to scale and how far, how to stop
without losing work, and what to do when the API answers badly. The backend
part is small and swappable. The code folder holds the controller, the
backend module, the worker, the producer, the stand-ins and the scripts that
produced every output in this talk, with a README that says how to run them.
Start with Docker on one machine, then move the same controller to VMs.
-->

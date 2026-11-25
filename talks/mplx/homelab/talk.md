---
theme: carbon
ratio: 16:9
transition: slide
---

# Homelab automation with Jennifer

![Jennifer](jennifer-logo.png)

One nightly script that asks every box in the rack how it is doing and sends
a single summary: Proxmox™, Synology™, Unraid™, Frigate™ and Docker™.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
A homelab grows one box at a time, and each box has its own web interface,
its own alerts and its own idea of what is worth telling you. This talk builds
one program, about two hundred lines, that checks all of them every morning
and sends one message. Every output on the slides is from a real run, against
a fake homelab: a small Jennifer server on a loopback port that answers like
the five APIs, with invented data. The last slides show how that works.
-->

---

## The lab and the question

| Box | What we want to know |
| --- | --- |
| Proxmox VE | production guests running, storage not full, backups OK |
| Synology NAS | volumes healthy, disks not failing, Hyper Backup™ done |
| Unraid server | array started, disk errors, containers that should run |
| Frigate NVR | people seen overnight, cameras that keep dropping |
| Docker host | containers that are not running |

**Goal:** one notification at 06:00, quiet when all is well, exit code 1 when not.

<!-- notes:
Each of these boxes can send its own e-mail, and that is the problem: five
senders, five formats, and the important line hidden in the noise. Instead we
ask each box the same kind of question, collect the answers as lines of text,
and send them together. The checks are deliberately boring: is it running, is
it full, did last night's job fail. Boring checks are the ones you actually
read every morning.
-->

---

## Five decks, one per API

| Deck | Speaks | Signs in with |
| --- | --- | --- |
| `@deckyard/proxmox` | REST, `/api2/json` | API token |
| `@deckyard/synology` | DSM™ Web API, `entry.cgi` | account and password, a session |
| `@deckyard/unraid` | GraphQL | API key |
| `@deckyard/frigate` | REST, `/api` | user and password (port 8971) |
| `@deckyard/docker` | Docker Engine API | none: guard the socket |

```sh
jvc add @deckyard/proxmox
jvc add @deckyard/synology   # ... and the other three
```

<!-- notes:
All five are community decks from Deckyard, each a client for one product.
They share a style: a Client value built with client and a chain of with
functions, typed structs for what comes back, and one error struct per deck
that carries the HTTP status. Every deck needs the net capability and nothing
else, so the script declares that in its header. jvc copies the decks into
vendor, and the imports read import "@deckyard/proxmox/" as proxmox.
-->

---

## Credentials: read-only, from the environment

- **Proxmox:** an API token with privilege separation and a read-only role
- **Synology:** an account of its own; storage and backup status need an
  administrator, so keep it off everything else
- **Unraid:** `unraid-api apikey --create --name automation --roles VIEWER`
- **Frigate:** port 8971 with `frigate.login`, or port 5000 on a trusted network
- **Docker:** the socket is root: an SSH tunnel to `127.0.0.1:2375`, or an
  https socket proxy with `docker.withToken`

```ini
EnvironmentFile=/etc/homelab-report.env   # mode 0600, root only
```

<!-- notes:
A monitoring script runs every day, unattended, so it should hold as little
power as possible. A Proxmox token with privilege separation gets only the
roles you grant it; a read-only one such as PVEAuditor is enough here. The
Unraid VIEWER role reads everything and changes nothing. The Docker deck does
not speak to a Unix socket yet, and whoever reaches the Engine API is root on
that machine, so tunnel it over SSH to loopback. Never print a Client: it
holds the secret in plain fields.
-->

---

## Proxmox: guests and tags

```jennifer excerpt
def c as proxmox.Client init proxmox.withToken(
    proxmox.client(os.getEnv("PVE_URL")),
    os.getEnv("PVE_TOKEN_ID"), os.getEnv("PVE_SECRET"));
for (def g in proxmox.guests($c)) {
    if ($g.template) { continue; }
    $total = $total + 1;
    if ($g.status == "running") {
        $running = $running + 1;
    } elseif (lists.contains($g.tags, "prod")) {
        $out[] = "WARN proxmox: {$g.name} ({$g.vmid}) is {$g.status}";
    }
}
```

```text
WARN proxmox: gitea (102) is stopped
```

<!-- notes:
client takes a host or a URL and adds https and port 8006 to a bare host.
guests asks the cluster once for every VM and container on every node and
returns them sorted by id, templates included, so we skip those. Tags are the
trick that keeps the rule short: only guests tagged prod in Proxmox count as a
problem when they are stopped, so a playground VM that is off on purpose stays
quiet. Tagging is done in the Proxmox web interface, no list in the script.
-->

---

## Proxmox: storage and last night's backups

```jennifer excerpt
for (def n in proxmox.nodes($c)) {
    for (def s in proxmox.storages($c, $n.node)) {
        def p as int init percent($s.used, $s.total);
        if ($s.active and $p >= FULL_PERCENT) { ... }
    }
}
for (def t in proxmox.recentTasks($c)) {
    if ($t.status == "stopped" and $t.exitStatus != "OK") { ... }
}
```

```text
WARN proxmox: storage local-zfs on pve1 is 90% full
WARN proxmox: vzdump 102 failed: ERROR: guest 102 is not running
ok   proxmox: 2 of 4 guests running
```

<!-- notes:
Storage is per node, so we walk the nodes first. percent is a three-line
helper with integer division, and FULL_PERCENT is a constant, 85. Proxmox runs
backups as vzdump tasks, and the cluster's task list keeps the recent ones
with their exit status: OK, or the error text. A failed backup is exactly the
kind of thing nobody notices for weeks. The three dots stand for the lines
that add a warning to the list, as on the slide before.
-->

---

## Synology: a session, volumes and disks

```jennifer excerpt
def c as synology.Client init synology.login(
    synology.client(os.getEnv("DSM_URL")),
    os.getEnv("DSM_USER"), os.getEnv("DSM_PASSWORD"));
defer synology.logout($c);
for (def d in synology.disks($c)) {
    if ($d.smartStatus != "normal" or $d.temperature > 50) {
        $out[] = "WARN synology: {$d.name} SMART {$d.smartStatus}, " +
            "{$d.temperature} C";
    }
}
```

```text
WARN synology: Drive 2 SMART failing, 41 C
```

<!-- notes:
DSM works with sessions. login first asks SYNO.API.Info where each API lives,
then logs in and keeps the session id and CSRF token in the client; every
request is a POST, so neither ends up in a URL or a log. defer logs out when
the function ends, however it ends, even when a later call throws. volumes
works the same way: a volume whose status is not normal, or one too full,
becomes a warning.
-->

---

## Synology: did Hyper Backup run?

```jennifer excerpt
for (def b in synology.backupTasks($c)) {
    def s as synology.BackupTask init synology.backupStatus($c, $b.id);
    if ($s.lastResult != "done") {
        $out[] = "WARN synology: backup {$s.name}: {$s.lastResult} " +
            "at {$s.lastTime}";
    }
}
```

```text
WARN synology: backup photos: failed at 2026-11-18 02:30
ok   synology: volumes, disks and backups checked
```

<!-- notes:
backupTasks lists the Hyper Backup tasks, but DSM leaves the result of the
last run out of that list; backupStatus asks for it task by task. A backup
that silently stopped working is the classic homelab disaster, discovered on
the day you need the restore. If Hyper Backup is not installed, backupTasks
throws a SynologyError, and the guard we see later turns that into a FAIL
line instead of a crash.
-->

---

## Unraid: the array over GraphQL

```jennifer excerpt
def c as unraid.Client init unraid.withApiKey(
    unraid.client(os.getEnv("UNRAID_URL")), os.getEnv("UNRAID_KEY"));
def a as unraid.StorageArray init unraid.array($c);
for (def d in $a.disks) {
    if ($d.errors > 0 or $d.status != "DISK_OK") { ... }
}
for (def ct in unraid.containers($c)) {
    if ($ct.autoStart and $ct.state != "RUNNING") { ... }
}
```

```text
WARN unraid: disk3 DISK_OK, 12 errors
WARN unraid: container paperless is Exited (137) 3 hours ago
ok   unraid: array STARTED, 60% used
```

<!-- notes:
Unraid's API is GraphQL, but the deck hides that: array returns one struct
with the state, the capacity, every disk and the last parity check. A disk
can say DISK_OK and still count read errors, which is often the first sign of
a dying drive or a loose cable. For containers, autoStart is the useful
filter: a container that starts with the array is meant to run, one that does
not is probably a tool you start by hand.
-->

---

## Frigate: who came by, which camera drops

```jennifer excerpt
def since as int init time.unix(time.now()) - 24 * 3600;
def people as list of frigate.Event init frigate.events($c,
    ["after={$since}", "label=person", "limit=20"]);
for (def cam in frigate.cameraStats($c)) {
    if ($cam.cameraFps == 0.0 or $cam.reconnects > 3) { ... }
}
```

```text
note frigate: person on driveway at 02:14 UTC
WARN frigate: camera garden: poor, 7 reconnects
ok   frigate: 1 person event(s) in 24 hours
```

<!-- notes:
events passes Frigate's own query parameters through, with their snake_case
names, so the server does the filtering: people in the last 24 hours, at most
twenty. Times are Unix seconds as floats. cameraStats turns the stats endpoint
into one struct per camera; a camera with no frames or many reconnects in the
last hour is usually a Wi-Fi or power problem. A note is information, not a
warning, and does not set the exit code.
-->

---

## Docker: everything that is not running

```jennifer excerpt
def c as docker.Client init docker.negotiate(
    docker.client(os.getEnv("DOCKER_URL")));   # tcp://127.0.0.1:2375
def all as list of docker.Container init docker.containers($c, true, []);
for (def ct in $all) {
    if ($ct.state != "running") {
        $out[] = "WARN docker: {$ct.name} ({$ct.image}) is {$ct.state}: " +
            "{$ct.status}";
    }
}
```

```text
WARN docker: uptime-kuma (louislam/uptime-kuma:1) is restarting: Restarting (1) 20 seconds ago
```

<!-- notes:
negotiate asks the daemon for its API version and uses the lower of that and
the newest the deck knows, so the same script works against an old and a new
Docker. containers with all set to true includes stopped ones, and the empty
list means no filters. A container stuck in restarting is worse than a
stopped one: it is crashing in a loop. The deck speaks Podman's compatible
API as well.
-->

---

## One failure must not hide the rest

```jennifer excerpt
func guarded(name as string) {
    try {
        match ($name) {
            when "proxmox" { return checkProxmox(); }
            # ... synology, unraid, frigate
            else { return checkDocker(); }
        }
    } catch (e) {
        return ["FAIL {$name} ({$e.kind}): {$e.message}"];
    }
}
```

```text
FAIL docker (net): net.connect: 127.0.0.1:2375: dial tcp 127.0.0.1:2375: connect: connection refused
```

<!-- notes:
Every check can fail: a box is down for maintenance, a password changed, a
certificate expired. Each deck throws a struct with a kind: net for a host
that cannot be reached, proxmox, synology or unraid for an API error with the
HTTP status in a field, limit or timeout for the generic cases. The guard
turns any of them into one FAIL line, so a dead Docker host still lets the
report about the other four through. The line above is a real run with the
SSH tunnel down.
-->

---

## Five checks at once

```jennifer excerpt
def checks as list of task of list of string;
for (def name in ["proxmox", "synology", "unraid", "frigate", "docker"]) {
    $checks[] = spawn {
        return guarded($name);
    };
}
for (def t in $checks) {
    for (def line in task.wait($t)) {
        $lines[] = $line;
    }
}
```

<!-- notes:
The checks do not depend on each other, so they run concurrently. spawn
starts each one as a task and copies what it needs, so tasks share no
variables and cannot race. task.wait collects the results in the order the
tasks were started, which keeps the report in a fixed order however fast each
box answers. The slowest box now sets the run time, not the sum of all five.
Because guarded catches everything, no task ever ends with an error.
-->

---

## The report

```text
WARN proxmox: gitea (102) is stopped
WARN proxmox: storage local-zfs on pve1 is 90% full
WARN proxmox: vzdump 102 failed: ERROR: guest 102 is not running
ok   proxmox: 2 of 4 guests running
WARN synology: Drive 2 SMART failing, 41 C
WARN synology: backup photos: failed at 2026-11-18 02:30
WARN unraid: disk3 DISK_OK, 12 errors
WARN unraid: container paperless is Exited (137) 3 hours ago
note frigate: person on driveway at 02:14 UTC
WARN frigate: camera garden: poor, 7 reconnects
WARN docker: uptime-kuma (louislam/uptime-kuma:1) is restarting: ...
ok   docker: 3 containers
```

<!-- notes:
This is the output of one run against the fake lab, which was built to have
something wrong everywhere; three of the ok lines are left out to fit the
slide. A good morning is five ok lines. Every line
starts with a fixed-width word, so the eye finds the warnings, and grep finds
them too. The format is plain text on purpose: it reads the same in a
terminal, an e-mail, a phone notification and a log file. The whole run took
about a tenth of a second on loopback.
-->

---

## Sending it

```jennifer excerpt
def importance as string init "INFO";
if ($warnings > 0) { $importance = "WARNING"; }
unraid.notify($u, "Homelab", "nightly: {$warnings} warning(s)", $report,
    $importance, "");
if ($warnings > 0) { exit 1; }
```

- Unraid's notification agents forward it: e-mail, push, chat
- Or a bot: see [How to code a Telegram™ bot](https://academy.jennifer-lang.dev/talks/mplx/telegram-bot/)
- Exit code 1 marks the run failed for systemd and for any other monitor

<!-- notes:
We already have a box that knows how to notify people: Unraid raises a
notification like its own alerts, shows it in the web interface, and its
notification settings decide where alerts go, e-mail or a push service. The importance follows the warnings, so a
quiet morning is an INFO. If you prefer a chat message, the Telegram deck
sends one in three lines. The exit code makes the failure visible to systemd,
which records it in the journal.
-->

---

## Every morning at six: a systemd timer

```ini
# /etc/systemd/system/homelab-report.service
[Service]
Type=oneshot
ExecStart=/usr/bin/jennifer run /opt/homelab/nightly.j
EnvironmentFile=/etc/homelab-report.env
DynamicUser=yes

# /etc/systemd/system/homelab-report.timer
[Timer]
OnCalendar=*-*-* 06:00:00
Persistent=true
```

<!-- notes:
A oneshot service runs the script once; the timer starts it every morning,
and Persistent catches up a run missed while the machine was off. Enable the
timer with systemctl enable --now homelab-report.timer and give the timer an
Install section with WantedBy=timers.target. DynamicUser runs it as a
throwaway user, which is fine because it needs no files of its own. The
journal keeps every report: journalctl -u homelab-report shows them.
-->

---

## Testing without a lab

```sh
jennifer run fake.j 28771 &
PVE_URL=http://127.0.0.1:28771 DOCKER_URL=tcp://127.0.0.1:28771 \
  ... jennifer run nightly.j
```

- `fake.j`: about 190 lines on `httpd`, one port for all five APIs,
  routed by path: `/api2/json`, `/webapi`, `/graphql`, `/api`, `/v1.51`
- Canned JSON with something wrong in each, logged per request
- Plain `http` is fine on loopback; the decks refuse it to another host
  unless asked (`frigate.withPlainHttp`, `docker.withPlainHttp`)

<!-- notes:
The script cannot tell the fake from the real thing, because the decks only
see HTTP. The fake answers just the endpoints the script uses, with JSON
shaped like the real replies, and logs every request, which shows the five
checks really run side by side. Each deck also ships a test suite with its
own scripted fake. Testing against invented data is also the polite way to
show a talk: no real camera events, no real host names.
-->

---

## Take-aways and read more

- One script, five decks, one report: **plain lines, one guard, one notification**
- Read-only credentials; never print a `Client`
- More decks for the lab: `@deckyard/jellyfin`, `@deckyard/vmware`,
  `@deckyard/virtualbox`, `@deckyard/onvif`
- Decks: [proxmox](https://registry.jennifer-lang.dev/deck/deckyard/proxmox),
  [synology](https://registry.jennifer-lang.dev/deck/deckyard/synology),
  [unraid](https://registry.jennifer-lang.dev/deck/deckyard/unraid),
  [frigate](https://registry.jennifer-lang.dev/deck/deckyard/frigate),
  [docker](https://registry.jennifer-lang.dev/deck/deckyard/docker)
- The language: [jennifer-lang.dev](https://jennifer-lang.dev/)

Based on Jennifer 0.27.0, November 2026.

<!-- notes:
The pattern carries over to anything with an API: one function per system
that returns lines, a guard around each, spawn to run them together, one
place that sends. Start with the check that would have saved you last time,
and add one rule at a time. Each deck has a manual with guides and a
cheatsheet of every function, linked from its repository; the registry at
registry.jennifer-lang.dev lists the rest.
-->

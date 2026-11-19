#!/usr/bin/env -S jennifer run
# Converge MikroTik routers to the desired state in devices/*.toml: read,
# plan, dry run, back up, apply with an undo list, verify, roll back.
#   jennifer run converge.j [--dry-run] [devices/x.toml ...]
# Credentials from the environment: MT_USER, MT_PASSWORD and
# MT_BACKUP_PASSWORD; MT_VERBOSE=1 prints every command sent.

use io;
use os;
use fs;
use path;
use toml;
use maps;
use lists;
use strings;
use time;
use channel;
use task;

import "@deckyard/routeros/" as mt;

def const LIMIT as int init 4;          # devices converged at once
def const OWNED as string init "iac:";  # comment prefix of our items

def struct Item {
    path as string,
    comment as string,
    attrs as map of string to string
};

def struct Desired {
    name as string,
    host as string,
    port as int,
    tls as bool,
    identity as string,
    dns as string,
    items as list of Item
};

# the router as read: identity, DNS servers, the rows of every path we own
def struct State {
    identity as string,
    dns as string,
    rows as map of string to list of map of string to string
};

# op: identity, dns, add, set or remove; old holds what it replaces
def struct Change {
    op as string,
    path as string,
    comment as string,
    id as string,
    attrs as map of string to string,
    old as map of string to string
};

def struct Report {
    name as string,
    ok as bool,
    lines as list of string
};

# --- loading the desired state ---

func load(file as string) {
    def doc as toml.Value init toml.decode(fs.readString($file));
    def want as Desired init Desired{
        name: toml.asString($doc, "/name"),
        host: toml.asString($doc, "/host"),
        port: 8729,
        tls: true,
        identity: toml.asString($doc, "/identity"),
        dns: toml.asString($doc, "/dns"),
        items: []
    };
    if (toml.has($doc, "/port")) { $want.port = toml.asInt($doc, "/port"); }
    if (toml.has($doc, "/tls")) { $want.tls = toml.asBool($doc, "/tls"); }
    for (def i in 0..toml.length($doc, "/item")) {
        def at as string init "/item/{$i}";
        def it as Item init Item{
            path: toml.asString($doc, $at + "/path"),
            comment: toml.asString($doc, $at + "/comment"),
            attrs: {}
        };
        for (def k in toml.keys($doc, $at)) {
            if ($k != "path") {
                $it.attrs[$k] = toml.asString($doc, $at + "/" + $k);
            }
        }
        if (not strings.startsWith($it.comment, OWNED)) {
            throw Error{kind: "value",
                message: "{$file}: item {$i}: the comment must start with {OWNED}"};
        }
        $want.items[] = $it;
    }
    return $want;
}

# the menu paths the file mentions, in file order
func paths(want as Desired) {
    def out as list of string;
    for (def it in $want.items) {
        if (not lists.contains($out, $it.path)) { $out[] = $it.path; }
    }
    return $out;
}

# --- read, then compute the difference ---

func readState(c as mt.Client, want as Desired) {
    def s as State init State{
        identity: mt.identity($c),
        dns: mt.dnsSettings($c).servers,
        rows: {}
    };
    for (def p in paths($want)) {
        $s.rows[$p] = mt.getAll($c, $p);
    }
    return $s;
}

func changed(want as map of string to string, row as map of string to string) {
    def out as map of string to string;
    for (def k in $want) {
        if (not maps.has($row, $k) or $row[$k] != $want[$k]) {
            $out[$k] = $want[$k];
        }
    }
    return $out;
}

func rowComment(row as map of string to string) {
    if (maps.has($row, "comment")) { return $row["comment"]; }
    return "";
}

func findByComment(rows as list of map of string to string, comment as string) {
    for (def row in $rows) {
        if (rowComment($row) == $comment) { return $row; }
    }
    def none as map of string to string;
    return $none;
}

# the attributes a removed row had, to add it back on undo
func settable(row as map of string to string) {
    def out as map of string to string;
    for (def k in $row) {
        if (not lists.contains([".id", "dynamic", "invalid"], $k)) { $out[$k] = $row[$k]; }
    }
    return $out;
}

func planPath(want as Desired, path as string, rows as list of map of string to string) {
    def out as list of Change;
    def wanted as list of string;
    for (def it in $want.items) {
        if ($it.path != $path) { continue; }
        $wanted[] = $it.comment;
        def row as map of string to string init findByComment($rows, $it.comment);
        if (len($row) == 0) {
            $out[] = Change{op: "add", path: $path, comment: $it.comment, id: "",
                attrs: $it.attrs, old: {}};
            continue;
        }
        def diff as map of string to string init changed($it.attrs, $row);
        if (len($diff) > 0) {
            def old as map of string to string;
            for (def k in $diff) {
                $old[$k] = "";
                if (maps.has($row, $k)) { $old[$k] = $row[$k]; }
            }
            $out[] = Change{op: "set", path: $path, comment: $it.comment,
                id: $row[".id"], attrs: $diff, old: $old};
        }
    }
    for (def row in $rows) {
        def comment as string init rowComment($row);
        if (strings.startsWith($comment, OWNED) and not lists.contains($wanted, $comment)) {
            $out[] = Change{op: "remove", path: $path, comment: $comment,
                id: $row[".id"], attrs: {}, old: settable($row)};
        }
    }
    return $out;
}

func plan(want as Desired, have as State) {
    def out as list of Change;
    if ($have.identity != $want.identity) {
        $out[] = Change{op: "identity", path: "", comment: "", id: "",
            attrs: {"name": $want.identity}, old: {"name": $have.identity}};
    }
    if ($have.dns != $want.dns) {
        $out[] = Change{op: "dns", path: "", comment: "", id: "",
            attrs: {"servers": $want.dns}, old: {"servers": $have.dns}};
    }
    for (def p in paths($want)) {
        $out = lists.concat($out, planPath($want, $p, $have.rows[$p]));
    }
    return $out;
}

func describe(ch as Change) {
    if ($ch.op == "identity") {
        return "~ identity {$ch.old["name"]} -> {$ch.attrs["name"]}";
    }
    if ($ch.op == "dns") {
        return "~ dns {$ch.old["servers"]} -> {$ch.attrs["servers"]}";
    }
    if ($ch.op == "remove") {
        return "- {$ch.path} {$ch.comment}";
    }
    def line as string init "+ {$ch.path} {$ch.comment}";
    if ($ch.op == "set") { $line = "~ {$ch.path} {$ch.comment}"; }
    for (def k in $ch.attrs) {
        if ($k != "comment") { $line = $line + " " + $k + "=" + $ch.attrs[$k]; }
    }
    return $line;
}

# --- apply with an undo list ---

# applies one change and returns the change that undoes it
func applyOne(c as mt.Client, ch as Change) {
    def undo as Change init $ch;
    $undo.attrs = $ch.old;
    $undo.old = $ch.attrs;
    if ($ch.op == "identity") {
        mt.setIdentity($c, $ch.attrs["name"]);
    } elseif ($ch.op == "dns") {
        mt.setDnsServers($c, $ch.attrs["servers"]);
    } elseif ($ch.op == "add") {
        $undo.id = mt.add($c, $ch.path, $ch.attrs);
        $undo.op = "remove";
    } elseif ($ch.op == "set") {
        mt.set($c, $ch.path, $ch.id, $ch.attrs);
    } else {
        mt.remove($c, $ch.path, $ch.id);
        $undo.op = "add";
    }
    return $undo;
}

func apply(c as mt.Client, changes as list of Change) {
    def undo as list of Change;
    try {                                   # in apply()
        for (def ch in $changes) { $undo[] = applyOne($c, $ch); }
    } catch (e) {
        for (def u in lists.reverse($undo)) { applyOne($c, $u); }
        throw $e;
    }
}

# --- one device ---

func converge(want as Desired, dryRun as bool) {
    def c as mt.Client init mt.connectWith(
        $want.host,
        $want.port,
        os.getEnv("MT_USER"),
        os.getEnv("MT_PASSWORD"),
        $want.tls);
    defer mt.disconnect($c);
    def changes as list of Change init plan($want, readState($c, $want));
    if (len($changes) == 0) { return ["in sync"]; }
    def lines as list of string;
    for (def ch in $changes) { $lines[] = describe($ch); }
    if ($dryRun) { return $lines; }
    def stamp as string init time.format(time.now(), "%Y%m%d-%H%M%S");
    def pw as string init os.getEnv("MT_BACKUP_PASSWORD");
    mt.saveBackupWith($c, "iac-" + $stamp, $pw);
    apply($c, $changes);
    if (len(plan($want, readState($c, $want))) > 0) {
        throw Error{kind: "value", message: "not converged"};
    }
    $lines[] = "applied {len($changes)} change(s), verified";
    return $lines;
}

func runDevice(file as string, dryRun as bool) {
    def r as Report init Report{name: strings.replace(path.base($file), ".toml", ""),
        ok: false, lines: []};
    try {                                   # in runDevice()
        $r.lines = converge(load($file), $dryRun);
        $r.ok = true;
    } catch (e) {
        if ($e.kind == "mikrotik") {        # mikrotik.MikrotikError
            $r.lines = ["refused, rolled back: " + $e.routerMessage];
        } elseif ($e.kind == "net") {       # net.NetError
            $r.lines = ["unreachable: " + $e.reason];
        } else {
            $r.lines = [$e.kind + ": " + $e.message];
        }
    }
    return $r;
}

func worker(jobs as channel of string, dryRun as bool) {
    def out as list of Report;
    while (true) {                          # in worker()
        try {
            $out[] = runDevice(channel.recv($jobs), $dryRun);
        } catch (e) {
            if ($e.kind != "closed") { throw $e; }
            return $out;
        }
    }
}

# --- many devices at once, at most LIMIT ---

def dryRun as bool init false;
def files as list of string;
for (def a in os.ARGS[1..]) {
    if ($a == "--dry-run") {
        $dryRun = true;
    } else {
        $files[] = $a;
    }
}
if (len($files) == 0) {
    for (def f in lists.sort(fs.list("devices"))) {
        if (strings.endsWith($f, ".toml")) { $files[] = "devices/" + $f; }
    }
}

def jobs as channel of string init channel.make(len($files));
def workers as list of task of list of Report;
for (def f in $files) { channel.send($jobs, $f); }
channel.close($jobs);
for (def n in 0..LIMIT) {
    $workers[] = spawn { return worker($jobs, $dryRun); };
}

def reports as map of string to Report;
for (def w in $workers) {
    for (def r in task.wait($w)) { $reports[$r.name] = $r; }
}
def failed as int init 0;
for (def name in lists.sort(maps.keys($reports))) {
    for (def line in $reports[$name].lines) {
        io.printf("%s  %s\n", $name, $line);
    }
    if (not $reports[$name].ok) { $failed = $failed + 1; }
}
if ($failed > 0) { exit 1; }

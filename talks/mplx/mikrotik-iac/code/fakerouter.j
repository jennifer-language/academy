#!/usr/bin/env -S jennifer run
# A fake RouterOS API service for the demo: one plain API listener on
# 127.0.0.1 per state file, speaking the binary API sentences. It knows
# /login, print, add, set and remove on any menu path, the identity and DNS
# singletons, /system/backup/save and /file. State lives in memory, so a
# second converge run sees the first run's changes. Only the user and
# password below log in. Never a stand-in for testing against a real router.
#   jennifer run fakerouter.j fake/branch-07.toml fake/branch-08.toml ...

use io;
use os;
use fs;
use net;
use toml;
use maps;
use lists;
use strings;
use convert;
use binary;
use task;

def const USER as string init "iac";
def const PASSWORD as string init "lab-only";

def struct Router {
    name as string,
    port as int,
    identity as string,
    dns as string,
    interfaces as list of string,
    rows as map of string to list of map of string to string,
    nextId as int
};

def struct Sentence {
    command as string,
    attrs as map of string to string
};

func load(file as string) {
    def doc as toml.Value init toml.decode(fs.readString($file));
    def r as Router init Router{
        name: toml.asString($doc, "/name"),
        port: toml.asInt($doc, "/port"),
        identity: toml.asString($doc, "/identity"),
        dns: toml.asString($doc, "/dns"),
        interfaces: [],
        rows: {},
        nextId: 1
    };
    for (def i in 0..toml.length($doc, "/interfaces")) {
        $r.interfaces[] = toml.asString($doc, "/interfaces/{$i}");
    }
    $r.rows["/file"] = [];
    for (def i in 0..toml.length($doc, "/row")) {
        def at as string init "/row/{$i}";
        def row as map of string to string;
        for (def k in toml.keys($doc, $at)) {
            $row[$k] = toml.asString($doc, $at + "/" + $k);
        }
        $r = addRow($r, $row);
    }
    return $r;
}

# --- the wire: length-prefixed words, a sentence ends with an empty word ---

func readExactly(conn as net.Conn, n as int) {
    def parts as list of bytes;
    def got as int init 0;
    while ($got < $n) {
        def chunk as bytes init net.readBytes($conn, $n - $got);
        if (len($chunk) == 0) {
            throw Error{kind: "closed", message: "peer closed"};
        }
        $parts[] = $chunk;
        $got = $got + len($chunk);
    }
    return binary.join($parts);
}

func readLength(conn as net.Conn) {
    def b as int init readExactly($conn, 1)[0];
    if (($b & 0x80) == 0) { return $b; }
    if (($b & 0xc0) == 0x80) {
        return (($b & 0x3f) << 8) | readExactly($conn, 1)[0];
    }
    def more as bytes init readExactly($conn, 2);
    return (($b & 0x1f) << 16) | ($more[0] << 8) | $more[1];   # enough here
}

func encodeLength(n as int) {
    def b as bytes;
    if ($n < 0x80) {
        $b[] = $n;
    } else {
        $b[] = ($n >> 8) | 0x80;
        $b[] = $n & 0xff;
    }
    return $b;
}

func readSentence(conn as net.Conn) {
    def s as Sentence init Sentence{command: "", attrs: {}};
    while (true) {
        def n as int init readLength($conn);
        if ($n == 0) { return $s; }
        def w as string init convert.stringFromBytes("utf-8", readExactly($conn, $n));
        if ($s.command == "") {
            $s.command = $w;
        } elseif (strings.startsWith($w, "=")) {
            def eq as int init strings.indexOf($w[1..], "=");
            $s.attrs[$w[1..$eq + 1]] = $w[$eq + 2..];
        }
    }
}

func writeSentence(conn as net.Conn, words as list of string) {
    def parts as list of bytes;
    for (def w in $words) {
        def raw as bytes init convert.bytesFromString("utf-8", $w);
        $parts[] = encodeLength(len($raw));
        $parts[] = $raw;
    }
    $parts[] = encodeLength(0);
    net.writeBytes($conn, binary.join($parts));
}

func attr(s as Sentence, key as string) {
    if (maps.has($s.attrs, $key)) { return $s.attrs[$key]; }
    return "";
}

func trap(conn as net.Conn, message as string) {
    writeSentence($conn, ["!trap", "=message=" + $message]);
    writeSentence($conn, ["!done"]);
}

# --- the router's menus ---

func addRow(r as Router, row as map of string to string) {
    def path as string init $row["path"];
    def stored as map of string to string init {".id": "*{$r.nextId}"};
    for (def k in $row) {
        if ($k != "path") { $stored[$k] = $row[$k]; }
    }
    if (not maps.has($stored, "disabled")) { $stored["disabled"] = "false"; }
    if (not maps.has($r.rows, $path)) { $r.rows[$path] = []; }
    $r.rows[$path][] = $stored;
    $r.nextId = $r.nextId + 1;
    return $r;
}

func findRow(r as Router, path as string, id as string) {
    if (maps.has($r.rows, $path)) {
        for (def i in 0..len($r.rows[$path])) {
            if ($r.rows[$path][$i][".id"] == $id) { return $i; }
        }
    }
    return -1;
}

# a RouterOS-like check: an address must name an existing interface
func badInput(r as Router, path as string, attrs as map of string to string) {
    if ($path == "/ip/address" and maps.has($attrs, "interface") and
        not lists.contains($r.interfaces, $attrs["interface"])) {
        return "input does not match any value of interface";
    }
    return "";
}

func printRows(r as Router, path as string) {
    if ($path == "/system/identity") { return [{"name": $r.identity}]; }
    if ($path == "/ip/dns") {
        return [{"servers": $r.dns, "allow-remote-requests": "false",
            "cache-size": "2048KiB", "cache-used": "24KiB"}];
    }
    if (maps.has($r.rows, $path)) { return $r.rows[$path]; }
    def none as list of map of string to string;
    return $none;
}

# one command; returns the router with its new state
func handle(r as Router, conn as net.Conn, s as Sentence) {
    def cmd as string init $s.command;
    def cut as int init strings.lastIndexOf($cmd, "/");
    def path as string init $cmd[0..$cut];
    def verb as string init $cmd[$cut + 1..];
    io.printf("%s: %s\n", $r.name, $cmd);
    if ($cmd == "/system/identity/set") {
        $r.identity = $s.attrs["name"];
    } elseif ($cmd == "/ip/dns/set") {
        $r.dns = $s.attrs["servers"];
    } elseif ($cmd == "/system/backup/save") {
        def f as map of string to string init {"path": "/file",
            "name": $s.attrs["name"] + ".backup", "type": "backup", "size": "24.1KiB"};
        $r = addRow($r, $f);
    } elseif ($verb == "print") {
        for (def row in printRows($r, $path)) {
            def words as list of string init ["!re"];
            for (def k in $row) { $words[] = "=" + $k + "=" + $row[$k]; }
            writeSentence($conn, $words);
        }
    } elseif ($verb == "add") {
        def bad as string init badInput($r, $path, $s.attrs);
        if ($bad != "") {
            trap($conn, $bad);
            return $r;
        }
        def row as map of string to string init $s.attrs;
        $row["path"] = $path;
        def id as string init "*{$r.nextId}";
        $r = addRow($r, $row);
        writeSentence($conn, ["!done", "=ret=" + $id]);
        return $r;
    } elseif ($verb == "set" or $verb == "remove") {
        def i as int init findRow($r, $path, attr($s, ".id"));
        def bad as string init badInput($r, $path, $s.attrs);
        if ($i < 0) { $bad = "no such item"; }
        if ($bad != "") {
            trap($conn, $bad);
            return $r;
        }
        if ($verb == "remove") {
            def rows as list of map of string to string init $r.rows[$path];
            $r.rows[$path] = lists.concat(lists.slice($rows, 0, $i),
                lists.slice($rows, $i + 1, len($rows)));
        } else {
            for (def k in $s.attrs) { $r.rows[$path][$i][$k] = $s.attrs[$k]; }
        }
    } else {
        trap($conn, "no such command prefix");
        return $r;
    }
    writeSentence($conn, ["!done"]);
    return $r;
}

# the next sentence, or an empty command once the client has gone
func next(conn as net.Conn) {
    try {
        return readSentence($conn);
    } catch (e) {
        if ($e.kind != "closed" and $e.kind != "net") { throw $e; }
        return Sentence{command: "", attrs: {}};
    }
}

func loggedIn(conn as net.Conn) {
    def login as Sentence init next($conn);
    if ($login.command == "/login" and attr($login, "name") == USER and
        attr($login, "password") == PASSWORD) {
        writeSentence($conn, ["!done"]);
        return true;
    }
    if ($login.command != "") { trap($conn, "invalid user name or password (6)"); }
    return false;
}

# one client after the other, until the process is stopped
func serve(r as Router) {
    def listener as net.Listener init net.listen("127.0.0.1:{$r.port}");
    io.printf("%s: RouterOS API on 127.0.0.1:%d\n", $r.name, $r.port);
    while (true) {   # until stopped # lint-disable: L105
        def conn as net.Conn init net.accept($listener);
        def open as bool init loggedIn($conn);
        while ($open) {
            def s as Sentence init next($conn);
            if ($s.command == "" or $s.command == "/quit") {
                $open = false;
            } else {
                $r = handle($r, $conn, $s);
            }
        }
        net.close($conn);
    }
}

def routers as list of task of null;
for (def file in os.ARGS[1..]) {
    def r as Router init load($file);
    $routers[] = spawn { return serve($r); };
}
for (def t in $routers) { task.wait($t); }

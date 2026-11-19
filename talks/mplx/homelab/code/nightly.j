#!/usr/bin/env -S jennifer run
# The nightly homelab report: asks Proxmox VE, a Synology NAS, an Unraid
# server, Frigate and a Docker host how they are, side by side, prints one
# report, sends it as an Unraid notification and exits 1 on any warning.
# Every address and credential comes from the environment (see README.md).
#   jennifer run nightly.j

use io;
use os;
use lists;
use strings;
use time;
use convert;
use task;

import "@deckyard/proxmox/" as proxmox;
import "@deckyard/synology/" as synology;
import "@deckyard/unraid/" as unraid;
import "@deckyard/frigate/" as frigate;
import "@deckyard/docker/" as docker;

def const FULL_PERCENT as int init 85;

func percent(used as int, total as int) {
    if ($total <= 0) { return 0; }
    return $used * 100 // $total;
}

func checkProxmox() {
    def out as list of string;
    def total as int init 0;
    def running as int init 0;
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
    for (def n in proxmox.nodes($c)) {
        for (def s in proxmox.storages($c, $n.node)) {
            def p as int init percent($s.used, $s.total);
            if ($s.active and $p >= FULL_PERCENT) {
                $out[] = "WARN proxmox: storage {$s.storage} on {$n.node} is {$p}% full";
            }
        }
    }
    for (def t in proxmox.recentTasks($c)) {
        if ($t.status == "stopped" and $t.exitStatus != "OK") {
            $out[] = "WARN proxmox: {$t.type} {$t.id} failed: {$t.exitStatus}";
        }
    }
    $out[] = "ok   proxmox: {$running} of {$total} guests running";
    return $out;
}

func checkSynology() {
    def out as list of string;
    def c as synology.Client init synology.login(
        synology.client(os.getEnv("DSM_URL")),
        os.getEnv("DSM_USER"), os.getEnv("DSM_PASSWORD"));
    defer synology.logout($c);
    for (def v in synology.volumes($c)) {
        def p as int init percent($v.usedBytes, $v.totalBytes);
        if ($v.status != "normal" or $p >= FULL_PERCENT) {
            $out[] = "WARN synology: volume {$v.path} {$v.status}, {$p}% full";
        }
    }
    for (def d in synology.disks($c)) {
        if ($d.smartStatus != "normal" or $d.temperature > 50) {
            $out[] = "WARN synology: {$d.name} SMART {$d.smartStatus}, " +
                "{$d.temperature} C";
        }
    }
    for (def b in synology.backupTasks($c)) {
        def s as synology.BackupTask init synology.backupStatus($c, $b.id);
        if ($s.lastResult != "done") {
            $out[] = "WARN synology: backup {$s.name}: {$s.lastResult} " +
                "at {$s.lastTime}";
        }
    }
    $out[] = "ok   synology: volumes, disks and backups checked";
    return $out;
}

func unraidClient() {
    return unraid.withApiKey(
        unraid.client(os.getEnv("UNRAID_URL")), os.getEnv("UNRAID_KEY"));
}

func checkUnraid() {
    def out as list of string;
    def c as unraid.Client init unraidClient();
    def a as unraid.StorageArray init unraid.array($c);
    for (def d in $a.disks) {
        if ($d.errors > 0 or $d.status != "DISK_OK") {
            $out[] = "WARN unraid: {$d.name} {$d.status}, {$d.errors} errors";
        }
    }
    for (def ct in unraid.containers($c)) {
        if ($ct.autoStart and $ct.state != "RUNNING") {
            $out[] = "WARN unraid: container {$ct.name} is {$ct.status}";
        }
    }
    def used as int init percent($a.usedKb, $a.totalKb);
    $out[] = "ok   unraid: array {$a.state}, {$used}% used";
    return $out;
}

func checkFrigate() {
    def out as list of string;
    def c as frigate.Client init frigate.client(os.getEnv("FRIGATE_URL"));
    if (os.getEnv("FRIGATE_USER") != "") {
        $c = frigate.login($c, os.getEnv("FRIGATE_USER"), os.getEnv("FRIGATE_PASSWORD"));
    }
    def since as int init time.unix(time.now()) - 24 * 3600;
    def people as list of frigate.Event init frigate.events($c,
        ["after={$since}", "label=person", "limit=20"]);
    for (def e in $people) {
        def at as string init time.format(
            time.fromUnix(convert.toInt($e.startTime)), "%H:%M");
        $out[] = "note frigate: {$e.label} on {$e.camera} at {$at} UTC";
    }
    for (def cam in frigate.cameraStats($c)) {
        if ($cam.cameraFps == 0.0 or $cam.reconnects > 3) {
            $out[] = "WARN frigate: camera {$cam.name}: {$cam.connection}, " +
                "{$cam.reconnects} reconnects";
        }
    }
    def n as int init len($people);
    $out[] = "ok   frigate: {$n} person event(s) in 24 hours";
    return $out;
}

func checkDocker() {
    def out as list of string;
    def c as docker.Client init docker.negotiate(
        docker.client(os.getEnv("DOCKER_URL")));   # tcp://127.0.0.1:2375
    def all as list of docker.Container init docker.containers($c, true, []);
    for (def ct in $all) {
        if ($ct.state != "running") {
            $out[] = "WARN docker: {$ct.name} ({$ct.image}) is {$ct.state}: " +
                "{$ct.status}";
        }
    }
    def n as int init len($all);
    $out[] = "ok   docker: {$n} containers";
    return $out;
}

func guarded(name as string) {
    try {
        match ($name) {
            when "proxmox" { return checkProxmox(); }
            when "synology" { return checkSynology(); }
            when "unraid" { return checkUnraid(); }
            when "frigate" { return checkFrigate(); }
            else { return checkDocker(); }
        }
    } catch (e) {
        return ["FAIL {$name} ({$e.kind}): {$e.message}"];
    }
}

def checks as list of task of list of string;
for (def name in ["proxmox", "synology", "unraid", "frigate", "docker"]) {
    $checks[] = spawn {
        return guarded($name);
    };
}
def lines as list of string;
for (def t in $checks) {
    for (def line in task.wait($t)) {
        $lines[] = $line;
    }
}

def warnings as int init 0;
for (def line in $lines) {
    if (strings.startsWith($line, "WARN") or strings.startsWith($line, "FAIL")) {
        $warnings = $warnings + 1;
    }
}
def report as string init strings.join($lines, "\n");
io.printf("%s\n", $report);

def importance as string init "INFO";
if ($warnings > 0) { $importance = "WARNING"; }
def u as unraid.Client init unraidClient();
try {
    unraid.notify($u, "Homelab", "nightly: {$warnings} warning(s)",
        $report, $importance, "");
} catch (e) {
    io.eprintf("notify failed (%s): %s\n", $e.kind, $e.message);
}
if ($warnings > 0) { exit 1; }

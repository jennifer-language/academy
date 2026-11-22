#!/usr/bin/env -S jennifer run
# A fake homelab: one loopback port that answers like the five APIs the
# nightly check uses, routed by path, with invented data and something wrong
# in each. Every request is logged. Never a stand-in for real hardware tests.
#   jennifer run fake.j 28771
#
#   /api2/json  Proxmox VE      /webapi   Synology DSM     /graphql  Unraid
#   /api        Frigate         /version and /v1.51   the Docker Engine API

use io;
use os;
use json;
use time;
use httpd;
use strings;
use convert;
use encoding;
import "uri.j" as uri;

def const GIB as int init 1073741824;

func reply(req as httpd.Request, status as int, body as string) {
    httpd.setHeader($req, "Content-Type", "application/json");
    httpd.respond($req, $status, $body);
}

# --- Proxmox VE: /api2/json, the data under "data" ---

func proxmox(path as string) {
    def d as string init "null";
    if ($path == "/cluster/resources") {
        $d = '[{"type": "lxc", "vmid": 100, "name": "dns", "node": "pve1", "status": "running", "tags": "prod"},' +
            '{"type": "qemu", "vmid": 101, "name": "nextcloud", "node": "pve1", "status": "running", "tags": "prod;web"},' +
            '{"type": "qemu", "vmid": 102, "name": "gitea", "node": "pve1", "status": "stopped", "tags": "prod"},' +
            '{"type": "qemu", "vmid": 103, "name": "scratch", "node": "pve1", "status": "stopped"},' +
            '{"type": "qemu", "vmid": 9000, "name": "debian-tmpl", "node": "pve1", "status": "stopped", "template": 1}]';
    } elseif ($path == "/nodes") {
        $d = '[{"node": "pve1", "status": "online", "cpu": 0.12, "maxcpu": 8}]';
    } elseif ($path == "/nodes/pve1/storage") {
        $d = '[{"storage": "local", "type": "dir", "content": "iso,vztmpl,backup", "active": 1, "enabled": 1,' +
            ' "total": ' + convert.toString(100 * GIB) + ', "used": ' + convert.toString(40 * GIB) + ', "avail": ' + convert.toString(60 * GIB) + '},' +
            '{"storage": "local-zfs", "type": "zfspool", "content": "images,rootdir", "active": 1, "enabled": 1,' +
            ' "total": ' + convert.toString(500 * GIB) + ', "used": ' + convert.toString(450 * GIB) + ', "avail": ' + convert.toString(50 * GIB) + '}]';
    } elseif ($path == "/cluster/tasks") {
        $d = '[{"upid": "UPID:pve1:1:1:1:vzdump:100:root@pam:", "node": "pve1", "type": "vzdump", "id": "100",' +
            ' "user": "root@pam", "endtime": 1763430000, "status": "OK"},' +
            '{"upid": "UPID:pve1:2:2:2:vzdump:102:root@pam:", "node": "pve1", "type": "vzdump", "id": "102",' +
            ' "user": "root@pam", "endtime": 1763430060, "status": "ERROR: guest 102 is not running"}]';
    }
    return '{"data": ' + $d + '}';
}

# --- Synology DSM: POST /webapi/<cgi>, the form names api and method ---

func synology(form as map of string to string) {
    def call as string init $form["api"] + " " + $form["method"];
    def d as string init '{}';
    if ($call == "SYNO.API.Info query") {
        $d = '{"SYNO.API.Auth": {"path": "entry.cgi", "minVersion": 1, "maxVersion": 7},' +
            ' "SYNO.Storage.CGI.Storage": {"path": "entry.cgi", "minVersion": 1, "maxVersion": 1},' +
            ' "SYNO.Backup.Task": {"path": "entry.cgi", "minVersion": 1, "maxVersion": 1}}';
    } elseif ($call == "SYNO.API.Auth login") {
        $d = '{"sid": "fake-session-id", "synotoken": "fake-csrf-token"}';
    } elseif ($call == "SYNO.Storage.CGI.Storage load_info") {
        $d = '{"disks": [{"id": "sata1", "name": "Drive 1", "model": "WD40EFRX", "status": "normal",' +
            ' "smart_status": "normal", "temp": 38, "size_total": "4000787030016"},' +
            '{"id": "sata2", "name": "Drive 2", "model": "WD40EFRX", "status": "normal",' +
            ' "smart_status": "failing", "temp": 41, "size_total": "4000787030016"}],' +
            ' "volumes": [{"id": "volume_1", "vol_path": "/volume1", "status": "normal", "fs_type": "btrfs",' +
            ' "size": {"total": "3800000000000", "used": "2100000000000"}}]}';
    } elseif ($call == "SYNO.Backup.Task list") {
        $d = '{"task_list": [{"task_id": 1, "name": "photos", "state": "backupable"},' +
            ' {"task_id": 2, "name": "documents", "state": "backupable"}]}';
    } elseif ($call == "SYNO.Backup.Task status" and $form["task_id"] == "1") {
        $d = '{"name": "photos", "state": "backupable", "status": "none",' +
            ' "last_bkp_result": "failed", "last_bkp_time": "2026-11-18 02:30"}';
    } elseif ($call == "SYNO.Backup.Task status") {
        $d = '{"name": "documents", "state": "backupable", "status": "none",' +
            ' "last_bkp_result": "done", "last_bkp_time": "2026-11-18 03:00"}';
    }
    return '{"success": true, "data": ' + $d + '}';
}

# --- Unraid: POST /graphql, told apart by the fields the query asks for ---

func unraid(query as string) {
    def d as string init '{}';
    if (strings.contains($query, 'array {')) {
        $d = '{"array": {"state": "STARTED", "capacity": {"kilobytes": {"total": "12000000000",' +
            ' "used": "7200000000", "free": "4800000000"}},' +
            ' "parityCheckStatus": {"status": "COMPLETED", "errors": 0},' +
            ' "parities": [{"id": "p1", "idx": 0, "name": "parity", "status": "DISK_OK", "numErrors": 0}],' +
            ' "disks": [{"id": "d1", "idx": 1, "name": "disk1", "status": "DISK_OK", "numErrors": 0},' +
            ' {"id": "d2", "idx": 2, "name": "disk2", "status": "DISK_OK", "numErrors": 0},' +
            ' {"id": "d3", "idx": 3, "name": "disk3", "status": "DISK_OK", "numErrors": 12}],' +
            ' "caches": []}}';
    } elseif (strings.contains($query, 'containers {')) {
        $d = '{"docker": {"containers": [' +
            '{"id": "c1", "names": ["/plex"], "image": "plexinc/pms-docker", "state": "RUNNING",' +
            ' "status": "Up 2 days", "autoStart": true, "ports": []},' +
            '{"id": "c2", "names": ["/paperless"], "image": "paperless-ngx/paperless-ngx", "state": "EXITED",' +
            ' "status": "Exited (137) 3 hours ago", "autoStart": true, "ports": []},' +
            '{"id": "c3", "names": ["/handbrake"], "image": "jlesage/handbrake", "state": "EXITED",' +
            ' "status": "Exited (0) 5 days ago", "autoStart": false, "ports": []}]}}';
    } elseif (strings.contains($query, "createNotification")) {
        $d = '{"createNotification": {"id": "n1", "title": "Homelab", "importance": "WARNING",' +
            ' "type": "UNREAD"}}';
    }
    return '{"data": ' + $d + '}';
}

# --- Frigate: /api ---

# the last 02:14 UTC before now, so the event is always inside 24 hours
func lastNight() {
    def now as int init time.unix(time.now());
    def t as int init $now - $now % 86400 + 2 * 3600 + 14 * 60;
    if ($t > $now) { $t = $t - 86400; }
    return $t;
}

func frigate(req as httpd.Request, path as string) {
    if ($path == "/login") {
        httpd.setHeader($req, "Set-Cookie",
            "frigate_token=eyJmYWtlIjoxfQ.eyJ1c2VyIjoiZmFrZSJ9.ZmFrZQ; Path=/");
        return '{}';
    }
    if ($path == "/events") {
        def t as int init lastNight();
        return '[{"id": "' + convert.toString($t) + '.0-ab12cd", "camera": "driveway", "label": "person",' +
            ' "top_score": 0.81, "start_time": ' + convert.toString($t) + '.0, "end_time": ' + convert.toString($t + 40) + '.0,' +
            ' "has_clip": true, "has_snapshot": true, "zones": []}]';
    }
    if ($path == "/stats") {
        return '{"cameras": {"driveway": {"camera_fps": 5.0, "process_fps": 5.0,' +
            ' "detection_fps": 0.2, "detection_enabled": true, "connection_quality": "excellent",' +
            ' "reconnects_last_hour": 0},' +
            ' "garden": {"camera_fps": 4.1, "process_fps": 4.1, "detection_fps": 0.0,' +
            ' "detection_enabled": true, "connection_quality": "poor", "reconnects_last_hour": 7}}}';
    }
    return "";
}

# --- the Docker Engine API ---

func docker(path as string) {
    if ($path == "/version") {
        return '{"Version": "28.5.1", "ApiVersion": "1.51", "MinAPIVersion": "1.24"}';
    }
    if ($path == "/v1.51/containers/json") {
        return '[{"Id": "a1", "Names": ["/traefik"], "Image": "traefik:v3", "State": "running",' +
            ' "Status": "Up 6 days"},' +
            '{"Id": "a2", "Names": ["/homepage"], "Image": "ghcr.io/gethomepage/homepage", "State": "running",' +
            ' "Status": "Up 6 days"},' +
            '{"Id": "a3", "Names": ["/uptime-kuma"], "Image": "louislam/uptime-kuma:1", "State": "restarting",' +
            ' "Status": "Restarting (1) 20 seconds ago"}]';
    }
    return "";
}

func route(req as httpd.Request) {
    def path as string init httpd.path($req);
    def body as string init encoding.decode("utf-8", httpd.body($req));
    def out as string init "";
    if (strings.startsWith($path, "/api2/json/")) {
        $out = proxmox($path[10..]);
    } elseif (strings.startsWith($path, "/webapi/")) {
        $out = synology(uri.parseQuery($body));
    } elseif ($path == "/graphql") {
        $out = unraid(json.asString(json.decode($body), "/query"));
    } elseif (strings.startsWith($path, "/api/")) {
        $out = frigate($req, $path[4..]);
    } elseif ($path == "/version" or strings.startsWith($path, "/v1.")) {
        $out = docker($path);
    }
    if ($out == "") {
        reply($req, 404, '{"message": "not in the fake"}');
        return;
    }
    reply($req, 200, $out);
}

def port as string init "28771";
if (len(os.ARGS) > 1) { $port = os.ARGS[1]; }
def srv as httpd.Server init httpd.listen("127.0.0.1:" + $port);
io.printf("fake homelab on http://127.0.0.1:%s\n", $port);
while (true) {   # until stopped # lint-disable: L105
    def req as httpd.Request init httpd.accept($srv);
    io.printf("%s %s\n", httpd.method($req), httpd.path($req));
    def keep as map of string to string;
    try {
        route($req);
    } catch (e) {
        $keep["error"] = $e.message;
        reply($req, 500, json.encode(json.map($keep)));
    }
}

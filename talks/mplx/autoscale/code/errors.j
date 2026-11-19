# What each deck throws when the backend says no.
import "@deckyard/docker/" as docker;
import "@deckyard/proxmox/" as proxmox;
import "@deckyard/virtualbox/" as virtualbox;
import "@deckyard/vmware/" as vmware;
use io;
use os;

func show(what as string, kind as string, status as string, message as string) {
    io.printf("%s|pad=24|align=left %s|pad=10|align=left %s|pad=4|align=left %s\n", $what,
        $kind, $status, $message);
}

def d as docker.Client init docker.negotiate(docker.client("tcp://127.0.0.1:12375"));
try {
    docker.createContainer($d, "academy-scale-w-x", docker.containerSpec("jennifer:no-such-tag"));
} catch (e) {
    def de as docker.DockerError init $e;
    show("docker: image missing", $de.kind, "{$de.status}", $de.message);
}
try {
    docker.containers(
        docker.withApiVersion(docker.client("tcp://127.0.0.1:12399"), "1.47"),
        true,
        []);
} catch (e) {
    show("docker: API unreachable", $e.kind, "-", $e.message);
}
def p as proxmox.Client init proxmox.withToken(
    proxmox.client("http://127.0.0.1:18006"),
    "autoscale@pve!ctl",
    "00000000-placeholder");
try {
    proxmox.guest($p, 9999);
} catch (e) {
    def pe as proxmox.ProxmoxError init $e;
    show("proxmox: no template", $pe.kind, "{$pe.status}", $pe.message);
}
try {
    proxmox.guests(proxmox.client("http://127.0.0.1:18006"));
} catch (e) {
    def pe as proxmox.ProxmoxError init $e;
    show("proxmox: no token", $pe.kind, "{$pe.status}", $pe.message);
}
def w as vmware.Client init vmware.login(
    vmware.client("http://127.0.0.1:18443"),
    "autoscale",
    "changeme");
try {
    vmware.powerOn($w, "vm-999");
} catch (e) {
    def we as vmware.VmwareError init $e;
    show("vmware: no such VM", $we.kind, "{$we.status}", $we.message);
}
try {
    vmware.vms(
        vmware.withSession($w, "expired"),
        vmware.VmFilter{
            vms: [],
            names: [],
            powerStates: [],
            hosts: [],
            clusters: [],
            datacenters: [],
            folders: [],
            resourcePools: []
        });
} catch (e) {
    def we as vmware.VmwareError init $e;
    show("vmware: session expired", $we.kind, "{$we.status}", $we.message);
}
def h as virtualbox.Host init virtualbox.open(virtualbox.withBinary(
    virtualbox.local(),
    os.getEnv("VBOXMANAGE")));
try {
    virtualbox.start($h, "no-such-vm");
} catch (e) {
    show("virtualbox: no such VM", $e.kind, virtualbox.errorCode($e), $e.message);
}

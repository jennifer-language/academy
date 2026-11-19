# One pool of workers on one of four backends. Every function takes the
# Backend and dispatches with match: Jennifer has no interfaces, and its
# func values carry no state, so the state lives in the enum's payloads.
import "@deckyard/docker/" as docker;
import "@deckyard/proxmox/" as proxmox;
import "@deckyard/virtualbox/" as virtualbox;
import "@deckyard/vmware/" as vmware;
use strings;
use convert;
use lists;

/** One managed worker, whatever runs it. state: running, stopped, other. */
export def struct Instance {
    id as string,
    name as string,
    state as string
};

/** Where workers run, and what each backend needs to make one. */
export def enum Backend {
    Docker{
        c as docker.Client,
        image as string,
        network as string,
        bind as string,
        env as map of string to string
    },
    Proxmox{c as proxmox.Client, template as int},
    Vbox{h as virtualbox.Host, template as string, snapshot as string},
    Vmware{c as vmware.Client, template as string, placement as vmware.Placement}
};

def const POOL_LABEL as string init "autoscale.pool";
def const CLONE_TIMEOUT_MS as int init 300000;

/** Whether a name belongs to this controller's pool. */
export func owned(name as string, prefix as string) {
    return strings.startsWith($name, $prefix);
}

/** The backend's name, for log lines. */
export func describe(b as Backend) {
    match ($b) {
        when Docker(d) { return "docker " + $d.image; }
        when Proxmox(p) { return "proxmox template " + convert.toString($p.template); }
        when Vbox(v) { return "virtualbox " + $v.template + "@" + $v.snapshot; }
        when Vmware(w) { return "vmware " + $w.template; }
    }
}

func dockerState(state as string) {
    match ($state) {
        when "running" { return "running"; }
        when "created", "exited", "dead" { return "stopped"; }
        else { return "other"; }
    }
}

func vmwareState(state as string) {
    match ($state) {
        when vmware.POWERED_ON { return "running"; }
        when vmware.POWERED_OFF { return "stopped"; }
        else { return "other"; }
    }
}

func noFilter() {
    def all as vmware.VmFilter; # the zero filter selects every VM
    return $all;
}

func dockerList(c as docker.Client, prefix as string) {
    def out as list of Instance init [];
    def filters as list of string init ["label=" + POOL_LABEL + "=" + $prefix];
    for (def k in docker.containers($c, true, $filters)) {
        if (owned($k.name, $prefix)) {
            $out[] = Instance{id: $k.id, name: $k.name, state: dockerState($k.state)};
        }
    }
    return $out;
}

func pveState(status as string) {
    if ($status == "running" or $status == "stopped") {
        return $status;
    }
    return "other";
}

func pveList(c as proxmox.Client, prefix as string) {
    def out as list of Instance init [];
    for (def g in proxmox.guests($c)) {
        if (owned($g.name, $prefix) and not $g.template) {
            def id as string init convert.toString($g.vmid);
            $out[] = Instance{id: $id, name: $g.name, state: pveState($g.status)};
        }
    }
    return $out;
}

func vboxList(h as virtualbox.Host, prefix as string) {
    def up as list of string init [];
    for (def m in virtualbox.runningVms($h)) {
        $up[] = $m.uuid;
    }
    def out as list of Instance init [];
    for (def m in virtualbox.vms($h)) {
        if (owned($m.name, $prefix)) {
            def state as string init "stopped";
            if (lists.contains($up, $m.uuid)) {
                $state = "running";
            }
            $out[] = Instance{id: $m.uuid, name: $m.name, state: $state};
        }
    }
    return $out;
}

func vmwareList(c as vmware.Client, prefix as string) {
    def out as list of Instance init [];
    for (def s in vmware.vms($c, noFilter())) {
        if (owned($s.name, $prefix)) {
            $out[] = Instance{id: $s.vm, name: $s.name, state: vmwareState($s.powerState)};
        }
    }
    return $out;
}

/** Every instance of this pool, and nothing else: label or name prefix. */
export func instances(b as Backend, prefix as string) {
    match ($b) {
        when Docker(d) { return dockerList($d.c, $prefix); }
        when Proxmox(p) { return pveList($p.c, $prefix); }
        when Vbox(v) { return vboxList($v.h, $prefix); }
        when Vmware(w) { return vmwareList($w.c, $prefix); }
    }
}

func pveGuest(c as proxmox.Client, id as string) {
    return proxmox.guest($c, convert.toInt($id));
}

/** Make a new instance and start it. */
export func create(b as Backend, prefix as string, name as string) {
    match ($b) {
        when Docker(d) {
            def env as map of string to string init $d.env;
            $env["WORKER_NAME"] = $name;
            def spec as docker.ContainerSpec init docker.containerSpec($d.image);
            $spec = docker.withCmd($spec, ["run", "/app/worker.j"]);
            $spec = docker.withEnv($spec, $env);
            $spec = docker.withLabels($spec, {POOL_LABEL: $prefix});
            $spec = docker.withBind($spec, $d.bind, "/app", true);
            $spec = docker.withNetworkMode($spec, $d.network);
            docker.startContainer($d.c, docker.createContainer($d.c, $name, $spec));
        }
        when Proxmox(p) {
            def id as int init proxmox.nextId($p.c);
            def upid as string init proxmox.linkedClone(
                $p.c,
                proxmox.guest($p.c, $p.template),
                $id,
                $name);
            def t as proxmox.Task init proxmox.waitTask($p.c, $upid, CLONE_TIMEOUT_MS);
            if ($t.exitStatus != "OK") {
                throw Error{kind: "scale", message: "clone " + $name + ": " + $t.exitStatus};
            }
            proxmox.start($p.c, proxmox.guest($p.c, $id));
        }
        when Vbox(v) {
            virtualbox.linkedClone($v.h, $v.template, $v.snapshot, $name);
            virtualbox.start($v.h, $name);
        }
        when Vmware(w) { vmware.cloneVm($w.c, $w.template, $name, $w.placement, true); }
    }
}

/** Start a stopped instance again (the warm pool). */
export func start(b as Backend, inst as Instance) {
    match ($b) {
        when Docker(d) { docker.startContainer($d.c, $inst.id); }
        when Proxmox(p) { proxmox.start($p.c, pveGuest($p.c, $inst.id)); }
        when Vbox(v) { virtualbox.start($v.h, $inst.id); }
        when Vmware(w) { vmware.powerOn($w.c, $inst.id); }
    }
}

/** Ask an instance to finish its job and stop: SIGTERM or ACPI, never a kill. */
export func drain(b as Backend, inst as Instance) {
    match ($b) {
        when Docker(d) { docker.killContainer($d.c, $inst.id, "SIGTERM"); }
        when Proxmox(p) { proxmox.shutdown($p.c, pveGuest($p.c, $inst.id), 0); }
        when Vbox(v) { virtualbox.acpiShutdown($v.h, $inst.id); }
        when Vmware(w) { vmware.shutdownGuest($w.c, $inst.id); }
    }
}

/** Delete a stopped instance. */
export func remove(b as Backend, inst as Instance) {
    match ($b) {
        when Docker(d) { docker.removeContainer($d.c, $inst.id, false, false); }
        when Proxmox(p) { proxmox.destroy($p.c, pveGuest($p.c, $inst.id), true); }
        when Vbox(v) { virtualbox.delete($v.h, $inst.id); }
        when Vmware(w) { vmware.deleteVm($w.c, $inst.id); }
    }
}

/** What a stopped instance said last, where the backend keeps a log. */
export func lastWords(b as Backend, inst as Instance) {
    match ($b) {
        when Docker(d) { return strings.trim(docker.logs($d.c, $inst.id, ["tail=1"]).stdout); }
        else { return ""; }
    }
}

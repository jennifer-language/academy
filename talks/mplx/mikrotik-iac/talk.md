---
theme: ember
ratio: 16:9
transition: none
---

# Infrastructure as code with Jennifer on MikroTik™ routers

![Jennifer](jennifer-logo.png)

Scripting the setup of new MikroTik™ devices with the RouterOS™ deck: desired
state in a file, a plan, a dry run, backup, apply, verify, roll back.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
This talk builds one program, about four hundred lines of Jennifer, that
configures a fleet of small routers from files in a repository. Every piece of
code on the slides comes from that program, and every output block is what it
printed. The routers in the demo are a fake RouterOS API service on loopback
ports, written in Jennifer too, so the run is repeatable on a laptop; the
program itself does not know the difference.
-->

---

## Why infrastructure as code

- **Clicking in WinBox™** works for one router. For thirty branch offices it
  means thirty slightly different configurations, and nobody knows which.
- **A file per device** in a repository: reviewed, diffed, versioned.
- **A program** that reads the router, compares, and changes only what
  differs: run it again and nothing happens.
- **Same steps every time:** dry run, backup, apply, verify, roll back on error.

<!-- notes:
Small routers tend to be configured by hand, one at a time, and then drift:
someone fixes a DNS server on one box at night and forgets the others. The
idea of infrastructure as code is to write down the state you want, keep it in
version control, and let a program make the device match. The important word
is idempotent: the second run must change nothing, otherwise you cannot run
it on a schedule or from CI.
-->

---

## The decks

| Deck | What it is |
| --- | --- |
| `@deckyard/routeros` | the thick layer: typed verbs for 56 topics, input validated before sending |
| `@jennifer/mikrotik` | the wire client: sessions, sentences, tags, `/listen` streams |

```sh
jvc add @deckyard/routeros   # into vendor/deckyard/routeros/
```

```jennifer
import "@deckyard/routeros/" as mt;
```

<!-- notes:
Two decks are involved. The routeros deck from Deckyard is the one to program
against: about 460 verbs such as setIdentity, setDnsServers, addBridge, plus
generic getAll, add, set and remove for any menu path. It validates input
locally, so a typo fails before anything is sent. Underneath it speaks the
binary API through the mikrotik client. In 0.27.0 that client is still the
bundled module, which is deprecated; the routeros deck moves to the
@jennifer/mikrotik deck before 0.28.0 removes the bundled copy. Your code does
not change: you import routeros either way.
-->

---

## Desired state: `devices/branch-07.toml`

```toml
name = "branch-07"
host = "10.7.0.1"
port = 8729
tls = true
identity = "branch-07"
dns = "9.9.9.9,149.112.112.112"
[[item]]
path = "/ip/address"
comment = "iac:lan"
address = "10.7.0.1/24"
interface = "bridge"
```

<!-- notes:
The file says what the router should look like, not how to get there. Two
settings, identity and DNS, plus a list of items, each under a RouterOS menu
path with its attributes under their RouterOS names. The comment is the handle:
RouterOS ids change when an item is re-created, comments do not. Everything
whose comment starts with "iac:" belongs to this program; everything else on
the router, the factory defaults included, is left alone. The demo files
point host and port at the local fake router and turn TLS off; otherwise they
are the same. Note what is not in the file: no user, no password.
-->

---

## Loading it

```jennifer excerpt
def doc as toml.Value init toml.decode(fs.readString($file));
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
```

<!-- notes:
TOML is Jennifer's config format and the toml library reads it with JSON
Pointer paths. The top-level keys go into a Desired struct the same way; this
is the loop over the items, which copies every key but the path into the
item's attribute map. The loader is strict: a missing key or a number where a string
belongs throws, and an item whose comment does not start with "iac:" is
refused, because the program would otherwise never find it again. Port and TLS
default to api-ssl on 8729. Everything lands in a plain struct, so the rest of
the program never touches TOML.
-->

---

## Connecting: api or api-ssl, secrets from the environment

```jennifer excerpt
def c as mt.Client init mt.connectWith(
    $want.host,
    $want.port,
    os.getEnv("MT_USER"),
    os.getEnv("MT_PASSWORD"),
    $want.tls);
defer mt.disconnect($c);
```

- `mt.connectTLS(host, user, password)`: api-ssl on 8729, certificate verified
- `mt.connect(...)`: plain API on 8728, the login in clear text: lab only
- a dedicated RouterOS user for the program, its password never in the repository

<!-- notes:
The credentials come from the environment: a CI secret, a systemd™ credential,
or a password manager that exports them. They are never in the device file, so
the repository can be read by everyone who reviews changes. Use api-ssl: the
plain API port sends the password in the clear on current RouterOS. Give the
program its own RouterOS user, so you can see its changes in the router's log
and revoke it alone. The defer closes the session however the function exits.
-->

---

## Read, then compute the difference

```jennifer
func changed(want as map of string to string, row as map of string to string) {
    def out as map of string to string;
    for (def k in $want) {
        if (not maps.has($row, $k) or $row[$k] != $want[$k]) {
            $out[$k] = $want[$k];
        }
    }
    return $out;
}
```

Per path: wanted but missing gives **add**, present but different gives **set**
(only the changed attributes), owned (`iac:`) but no longer wanted gives **remove**.

<!-- notes:
The program reads the current state with the deck: mt.identity, mt.dnsSettings
and mt.getAll for each path the file mentions. Then a pure function compares.
For one item it is this small: the attributes whose value differs. Around it,
the plan function walks every path and produces a list of changes, each with
the old values as well, which we need for the undo later. Because the plan is
pure, it is easy to test without a router.
-->

---

## Dry run: the plan, nothing changed

```text
$ jennifer run converge.j --dry-run
branch-07  ~ identity MikroTik -> branch-07
branch-07  ~ dns 8.8.8.8 -> 9.9.9.9,149.112.112.112
branch-07  ~ /ip/address iac:lan address=10.7.0.1/24
branch-07  + /ip/firewall/address-list iac:mgmt list=mgmt address=10.0.0.0/24
branch-07  - /ip/firewall/address-list iac:old-office
branch-08  in sync
branch-09  ~ identity MikroTik -> branch-09
branch-09  + /ip/address iac:lan address=10.9.0.1/24 interface=ether9
branch-10  unreachable: refused
```

<!-- notes:
This is the output of the real run against the fake routers, two lines of
branch-09 cut for space. Branch-07 has drifted: a wrong prefix on its LAN
address and an old address-list entry that was removed from the file. Branch-08
already matches. Branch-09 is new and needs everything. Branch-10 does not
answer. The dry run connects and reads, but never writes. Put this output in
the merge request, and let a reviewer approve exactly these lines.
-->

---

## Apply: backup first, keep an undo list

```jennifer excerpt
def pw as string init os.getEnv("MT_BACKUP_PASSWORD");
mt.saveBackupWith($c, "iac-" + $stamp, $pw);
apply($c, $changes);
if (len(plan($want, readState($c, $want))) > 0) {
    throw Error{kind: "value", message: "not converged"};
}
```

```jennifer excerpt
try {                                   # in apply()
    for (def ch in $changes) { $undo[] = applyOne($c, $ch); }
} catch (e) {
    for (def u in lists.reverse($undo)) { applyOne($c, $u); }
    throw $e;
}
```

<!-- notes:
Before the first write, an encrypted backup on the router; the deck checks that
the file appeared. Then each change is applied, and applying returns the change
that undoes it: an add returns a remove of the new id, a set returns a set with
the old values. If anything fails, the undo list runs backwards and the error
goes on to the caller. Last, verify: read again and plan again. An empty plan
is the proof that the router now matches the file.
-->

---

## Rollback in action

```text
$ MT_VERBOSE=1 jennifer run converge.j devices/branch-09.toml
mt> /system/backup/save name=iac-20261116-225017 password=<redacted>
mt> /file/print
mt< 1 row
mt> /system/identity/set name=branch-09
mt> /ip/dns/set servers=9.9.9.9,149.112.112.112
mt> /ip/address/add comment=iac:lan address=10.9.0.1/24 interface=ether9
mt> /ip/dns/set servers=8.8.8.8
mt> /system/identity/set name=MikroTik
branch-09  refused, rolled back: input does not match any value of interface
```

<!-- notes:
Branch-09's file names ether9, which that router does not have. With
MT_VERBOSE the deck prints every command before sending it, with passwords
redacted; the four reads before the backup are cut here. The backup is saved and checked, identity and DNS are set, the
address is refused, and the two changes are undone in reverse order. The
router is back where it was. The backup file is the last resort for what an
undo list cannot cover: restoring it reboots the router, so the deck leaves
that to the console.
-->

---

## Errors are typed structs

```jennifer excerpt
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
```

<!-- notes:
Each device ends in a report, so one failure never stops the others. Three
kinds matter. "routeros" is the deck's own validation: a bad name or
address, refused before any I/O. "mikrotik" is a mikrotik.MikrotikError: the
router answered with a trap, or the login failed; its fields carry the trap
category and the router's own message, so you never parse text. "net" is a
net.NetError: refused, reset, DNS, TLS, with sent and replied for retry
decisions. Match the kind first, then read the fields. Timeouts and closed
connections keep their generic kinds.
-->

---

## Many devices at once, at most four

```jennifer excerpt
for (def f in $files) { channel.send($jobs, $f); }
channel.close($jobs);
for (def n in 0..LIMIT) {
    $workers[] = spawn { return worker($jobs, $dryRun); };
}
```

```jennifer excerpt
while (true) {                          # in worker()
    try {
        $out[] = runDevice(channel.recv($jobs), $dryRun);
    } catch (e) {
        if ($e.kind != "closed") { throw $e; }
        return $out;
    }
}
```

<!-- notes:
A pool of LIMIT workers, each a spawn, all reading file names from one
buffered channel that holds every file and is then closed.
That caps the number of open API sessions, however many devices there are. Each
spawn gets its own copy of everything it uses, so workers share nothing but the
channel, and one slow or dead router never blocks the others: branch-10's
refused connection costs one worker a moment. A worker stops when recv reports
the drained channel with kind "closed". The main program waits for all
workers and prints the reports sorted by device name.
-->

---

## Run it, then run it again

```text
$ jennifer run converge.j; echo "exit $?"
branch-07  ~ /ip/address iac:lan address=10.7.0.1/24
branch-07  applied 5 change(s), verified
branch-08  in sync
branch-09  refused, rolled back: input does not match any value of interface
branch-10  unreachable: refused
exit 1
$ jennifer run converge.j
branch-07  in sync
branch-08  in sync
```

<!-- notes:
The first run applies branch-07's five changes (four plan lines cut here) and
verifies them. The exit code is 1 because two devices failed, so CI or a
systemd timer notices. The second run changes nothing on branch-07: that is
idempotence, and it means the program can run every night to catch drift.
Fix branch-09's file, bring branch-10 back online, and the next run converges
them too. The second run's lines for those two are cut from the slide.
-->

---

## Take-aways and read more

- Desired state in files, secrets in the environment, ownership by comment
- Read, plan, dry run, back up, apply with undo, verify: the same every time
- Branch on the error's kind, read its fields
- The deck: [deckyard/deck-routeros](https://registry.jennifer-lang.dev/deck/deckyard/routeros),
  the wire client: [jennifer-language/deck-mikrotik](https://registry.jennifer-lang.dev/deck/jennifer/mikrotik)
- The language: [jennifer-lang.dev](https://jennifer-lang.dev/), this talk in
  the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.27.0, November 2026.

<!-- notes:
The routeros deck itself has no plan or diff step and does not detect drift;
it applies what a script says. This talk added that layer in about four
hundred lines, on top of the deck's generic getAll, add, set and remove. The
deck's guides cover the typed verbs for bridges, VLANs, the firewall, DHCP and
WireGuard™, which make good next items for the device files. Test against a
lab router first: this program changes live network equipment.
-->

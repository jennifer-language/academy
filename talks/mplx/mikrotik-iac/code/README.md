# Code for "Infrastructure as code for MikroTik routers"

The program behind the slides, for Jennifer 0.26.0, and the fake routers
it was run against. Run everything from this folder. No real router is
touched: `fakerouter.j` is a stand-in for the RouterOS API service, written
in Jennifer, that listens on loopback ports and keeps its state in memory.

## Setup

```sh
jvc update     # reads deck.toml: @deckyard/routeros 0.3.0 into vendor/
export MT_USER=iac MT_PASSWORD=lab-only MT_BACKUP_PASSWORD=placeholder-backup-pw
```

The routeros deck speaks the binary API through the `mikrotik` module
bundled with Jennifer 0.26.0. The fake accepts only the user `iac` with the
password `lab-only`.

## Programs and files

| File | Shows (slides) | Run |
| --- | --- | --- |
| `converge.j` | the whole program: loading, connecting, the plan and `changed`, dry run, backup, apply with an undo list, verify, typed errors, the worker pool (3, 5 to 13) | `jennifer run converge.j [--dry-run] [devices/x.toml ...]` (default: every file in `devices/`) |
| `devices/branch-07.toml` ... `branch-10.toml` | the desired state per router (4). They point `host`, `port` and `tls` at the fake: 127.0.0.1, ports 18707 to 18710, plain API | read by `converge.j` |
| `fakerouter.j` | the stand-in routers: `/login`, print, add, set and remove on any path, identity, DNS, `/system/backup/save`, `/file`; refuses an address on an interface it lacks | `jennifer run fakerouter.j fake/branch-07.toml fake/branch-08.toml fake/branch-09.toml` |
| `fake/branch-07.toml` ... `branch-09.toml` | the fake routers' starting state: 07 has drifted, 08 matches, 09 is factory fresh without `ether9`; nothing listens for branch-10 | read by `fakerouter.j` |
| `run.sh` | the runs of slides 8, 10 and 13: dry run, the rollback on branch-09 with `MT_VERBOSE=1`, two real runs | `./run.sh` |

`run.sh` starts and stops the fake itself; it writes `fake.log` (every
command the fake received), delete it afterwards. The fake forgets
everything when it stops, so `./run.sh` starts from the same state each
time. Against a real router, use api-ssl (`tls = true`, port 8729), a
RouterOS user of its own, and test on a lab router first.

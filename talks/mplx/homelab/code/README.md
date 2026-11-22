# Code for "Homelab automation with Jennifer"

The nightly check behind the slides, for Jennifer 0.27.0, and the fake
homelab it was run against. Run everything from this folder. Nothing here
talks to a real Proxmox, Synology, Unraid, Frigate or Docker host: `fake.j`
is a stand-in written in Jennifer that answers the five APIs on one
loopback port with invented data.

## Setup

```sh
jvc update     # reads deck.toml: @deckyard/docker 0.2.0, frigate 0.4.0,
               # proxmox 0.2.0, synology 0.2.0, unraid 0.2.0 into vendor/
```

## Programs

| File | Shows (slides) | Run |
| --- | --- | --- |
| `nightly.j` | the whole script: Proxmox guests, storage and backups, Synology disks, volumes and Hyper Backup, the Unraid array and containers, Frigate events and cameras, Docker containers, the guard, five checks at once, the report and the Unraid notification (5 to 15) | see below |
| `fake.j` | the fake homelab: `/api2/json` (Proxmox VE), `/webapi` (DSM), `/graphql` (Unraid), `/api` (Frigate), `/version` and `/v1.51` (Docker); logs every request (17) | `jennifer run fake.j 28771` |
| `run.sh` | the report of slide 14, then the FAIL line of slide 12 with the Docker host unreachable | `./run.sh` |

`nightly.j` reads every address and credential from the environment. For
the fake, with placeholder values:

```sh
F=http://127.0.0.1:28771
PVE_URL=$F PVE_TOKEN_ID='report@pve!nightly' PVE_SECRET=00000000-0000-0000-0000-000000000000 \
DSM_URL=$F DSM_USER=report DSM_PASSWORD=placeholder \
UNRAID_URL=$F/graphql UNRAID_KEY=placeholder-key \
FRIGATE_URL=$F FRIGATE_USER=report FRIGATE_PASSWORD=placeholder \
DOCKER_URL=tcp://127.0.0.1:28771 jennifer run nightly.j
```

The fake accepts any credentials. Without `FRIGATE_USER`, `nightly.j`
skips `frigate.login` (Frigate's port 5000). Plain `http` works here
because the fake is on loopback. The exit code is 1 when any line is a
WARN or FAIL. `run.sh` starts and stops the fake and writes `fake.log`;
delete it afterwards. The systemd units of slide 16 are shown on the slide
only: install them on the machine that runs the report.

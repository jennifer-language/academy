# Code for "Dynamic workloads: autoscaling Resque workers with Jennifer"

Every program behind the slides, for Jennifer 0.26.0. Run everything from
this folder. The decks come from the registry: `jvc install` reads
`deck.toml` and copies them into `vendor/`.

## Setup

```sh
jvc install          # @deckyard/docker 0.2.0, proxmox 0.2.0, virtualbox 0.1.0, vmware 0.3.0
./setup.sh           # network academy-scale-net, Redis on 127.0.0.1:16390,
                     # the Docker API on 127.0.0.1:12375 (socat), the worker image
```

`setup.sh` runs these three containers and one pull:

```sh
docker network create --label academy-scale=1 academy-scale-net
docker run -d --name academy-scale-redis --label academy-scale=1 --network academy-scale-net -p 127.0.0.1:16390:6379 redis:7
docker run -d --name academy-scale-sock --label academy-scale=1 -p 127.0.0.1:12375:2375 -v /var/run/docker.sock:/var/run/docker.sock alpine/socat tcp-listen:2375,fork,reuseaddr unix-connect:/var/run/docker.sock
docker pull ghcr.io/jennifer-language/jennifer:0.26.0
```

Anyone on this machine who can reach 127.0.0.1:12375 is root on it while
the socat container runs. `./teardown.sh` removes every `academy-scale-*`
container and the network.

## Programs

| File | Shows (slides) | Run |
| --- | --- | --- |
| `controller.j` | the autoscaler: measuring, the rule, up fast and down slowly, limits, retries, reconciliation, logging (4 to 7, 16 to 18, 20 to 23) | `BACKEND=docker REDIS_PORT=16390 DOCKER_URL=tcp://127.0.0.1:12375 WORKER_DIR=$PWD/worker jennifer run controller.j` |
| `backend.j` | the Backend enum and the match dispatch for all four decks (10 to 15) | imported by `controller.j` |
| `worker/worker.j` | the worker: drains on SIGTERM, exits after 30 s idle (8, 9) | runs in the containers, mounted at `/app` |
| `enqueue.j` | a burst of jobs, each stamped with its enqueue time (5, 22) | `REDIS_PORT=16390 jennifer run enqueue.j --count 60 --queue thumbs` |
| `errors.j` | what each deck throws (19) | start both stand-ins, then `VBOXMANAGE=$PWD/standin/vboxmanage.sh jennifer run errors.j` |
| `standin/pve.j` | a stand-in for the Proxmox VE API calls the controller makes (14) | `jennifer run standin/pve.j --listen 127.0.0.1:18006` |
| `standin/vcenter.j` | a stand-in for the vCenter REST calls (15) | `jennifer run standin/vcenter.j --listen 127.0.0.1:18443` |
| `standin/vboxmanage.sh` | a stand-in `VBoxManage`, machines kept as files in `standin/vbox-state/` (13) | used through `VBOXMANAGE` |
| `run.sh` | the full Docker run: burst, controller killed and replaced, Docker API lost for 7 s, second burst (12, 16, 20 to 23) | `./run.sh`, then read `events.log`, `runA.log`, `runB.log`, `decisions.log` |
| `run_orphan.sh` | the controller stays dead; workers exit idle, a new controller reaps them (17) | `./run_orphan.sh` |
| `run_vm.sh` | the same controller against a stand-in; the jobs are deleted by hand, no worker runs (13 to 15) | `WARM=0 ./run_vm.sh proxmox`, `WARM=0 ./run_vm.sh vbox`, `WARM=1 ./run_vm.sh vmware` |

The controller reads its settings from the environment: `BACKEND`
(`docker`, `proxmox`, `vbox`, `vmware`), `REDIS_PORT`, `WARM` (stopped
clones to keep), `STOP_IDLE_AFTER` (seconds; stop once nothing runs or
waits, for the demos), and per backend `DOCKER_URL` and `WORKER_DIR`;
`PVE_URL`, `PVE_TOKEN_ID`, `PVE_SECRET`; `VBOXMANAGE`; `VCENTER_URL`,
`VCENTER_USER`, `VCENTER_PASSWORD`. The scripts set placeholder values that
only the stand-ins accept. `redis-cli SET autoscale:hold 1` freezes the pool.

The runs write their logs and `standin/vbox-state/` into this folder; delete
them afterwards.

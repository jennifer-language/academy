#!/bin/sh
# The controller dies and nobody restarts it for 45 s: the workers finish
# the queue and exit on their own; controller B then cleans up.
cd "$(dirname "$0")"
export REDIS_PORT=16390 DOCKER_URL=tcp://127.0.0.1:12375 BACKEND=docker
export WORKER_DIR="$PWD/worker"
T0=$(date +%s)
at() { while [ $(( $(date +%s) - T0 )) -lt "$1" ]; do sleep 0.2; done; echo "--- t=$1 s: $2" >> orphan-events.log; }
docker exec academy-scale-redis redis-cli FLUSHALL >/dev/null
rm -f orphan-events.log decisions.log
jennifer run controller.j > orphanA.log 2>&1 &
A=$!
at 2 "burst of 30"
jennifer run enqueue.j --count 30 --queue thumbs >> orphan-events.log
at 6 "kill -9 controller A"
kill -9 $A
at 50 "docker ps"
docker ps -a --filter label=autoscale.pool --format '{{.Names}}\t{{.Status}}' >> orphan-events.log
at 51 "controller B starts"
STOP_IDLE_AFTER=1 jennifer run controller.j > orphanB.log 2>&1

#!/bin/sh
# The end-to-end run against the local Docker daemon, with a controller
# restart and a lost Docker API in the middle.
cd "$(dirname "$0")"
export REDIS_PORT=16390 DOCKER_URL=tcp://127.0.0.1:12375 BACKEND=docker
export WORKER_DIR="$PWD/worker"
T0=$(date +%s)
at() { while [ $(( $(date +%s) - T0 )) -lt "$1" ]; do sleep 0.2; done; echo "--- t=$1 s: $2" >> events.log; }
docker exec academy-scale-redis redis-cli FLUSHALL >/dev/null
rm -f decisions.log events.log
docker run -d --name academy-scale-w-manual --label academy-scale=1 redis:7 >/dev/null
jennifer run controller.j > runA.log 2>&1 &
A=$!
at 3 "burst of 60"
jennifer run enqueue.j --count 60 --queue thumbs >> events.log
at 11 "docker ps"
docker ps -a --filter name=academy-scale-w- --format '{{.Names}}\t{{.Status}}\t{{.Label "autoscale.pool"}}' >> events.log
at 12 "kill -9 controller A"
kill -9 $A
at 15 "controller B starts"
STOP_IDLE_AFTER=50 jennifer run controller.j > runB.log 2>&1 &
B=$!
at 20 "Docker API proxy stopped"
docker stop -t 1 academy-scale-sock >/dev/null
at 27 "Docker API proxy started"
docker start academy-scale-sock >/dev/null
at 50 "burst of 8 on high"
jennifer run enqueue.j --count 8 --queue high >> events.log
wait $B
echo "--- t=$(( $(date +%s) - T0 )) s: controller B exit $?" >> events.log
docker ps -a --filter name=academy-scale-w- --format '{{.Names}}\t{{.Status}}' >> events.log

#!/bin/sh
# The same controller against a stand-in: run_vm.sh proxmox|vbox|vmware
# Nothing runs a worker here: the jobs are deleted by hand at t=8 s.
cd "$(dirname "$0")"
export REDIS_PORT=16390 BACKEND=$1 STOP_IDLE_AFTER=40
export PVE_URL=http://127.0.0.1:18006 PVE_TOKEN_ID='autoscale@pve!ctl' PVE_SECRET=00000000-placeholder
export VCENTER_URL=http://127.0.0.1:18443 VCENTER_USER=autoscale@vsphere.local VCENTER_PASSWORD=changeme
export VBOXMANAGE="$PWD/standin/vboxmanage.sh"
T0=$(date +%s)
at() { while [ $(( $(date +%s) - T0 )) -lt "$1" ]; do sleep 0.2; done; echo "--- t=$1 s: $2" >> vm-events.log; }
rm -rf vm-events.log; [ "$1" = vbox ] && rm -rf standin/vbox-state standin/vbox-calls.log
docker exec academy-scale-redis redis-cli FLUSHALL >/dev/null
case $1 in
  proxmox) jennifer run standin/pve.j --listen 127.0.0.1:18006 > standin-$1.log 2>&1 & S=$! ;;
  vmware) jennifer run standin/vcenter.j --listen 127.0.0.1:18443 > standin-$1.log 2>&1 & S=$! ;;
esac
sleep 1
jennifer run controller.j > vm-$1.log 2>&1 &
C=$!
at 2 "burst of 25"
jennifer run enqueue.j --count 25 --queue thumbs > /dev/null
at 8 "jobs deleted by hand"
docker exec academy-scale-redis redis-cli DEL resque:queue:thumbs > /dev/null
at 30 "burst of 5"
jennifer run enqueue.j --count 5 --queue thumbs > /dev/null
at 34 "jobs deleted by hand"
docker exec academy-scale-redis redis-cli DEL resque:queue:thumbs > /dev/null
wait $C
[ -n "$S" ] && kill $S
mv vm-events.log vm-$1.events.log

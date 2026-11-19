#!/bin/sh
# Remove every container and the network setup.sh and the runs created.
docker ps -aq --filter name=academy-scale- | xargs -r docker rm -f
docker network rm academy-scale-net
docker ps -a --filter name=academy-scale-

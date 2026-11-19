#!/bin/sh
# Redis, a network for the workers, and the Docker API on loopback TCP
# (the docker deck does not speak to the Unix socket). Everything is named
# and labelled academy-scale-*; teardown.sh removes it again.
set -e
docker network create --label academy-scale=1 academy-scale-net
docker run -d --name academy-scale-redis --label academy-scale=1 \
  --network academy-scale-net -p 127.0.0.1:16390:6379 redis:7
docker run -d --name academy-scale-sock --label academy-scale=1 \
  -p 127.0.0.1:12375:2375 -v /var/run/docker.sock:/var/run/docker.sock \
  alpine/socat tcp-listen:2375,fork,reuseaddr unix-connect:/var/run/docker.sock
docker pull ghcr.io/jennifer-language/jennifer:0.26.0

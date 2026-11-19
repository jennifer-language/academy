#!/bin/sh
# Writes passwd (user demo, password changeme) next to this script, using
# mosquitto_passwd from the broker image. Placeholder credentials only.
set -e
dir=$(cd "$(dirname "$0")" && pwd)
docker run --rm -v "$dir":/m eclipse-mosquitto:2 \
    sh -c 'mosquitto_passwd -b -c /m/passwd demo changeme && chmod 644 /m/passwd'

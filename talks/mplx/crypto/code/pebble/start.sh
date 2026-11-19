#!/bin/sh
# Start Let's Encrypt's test CA pebble on 127.0.0.1:14000, with
# pebble-challtestsrv as its DNS server so shelf.example.test resolves to
# 127.0.0.1. Host networking, because pebble must reach the challenge
# server acme1.j opens on 127.0.0.1:5002. Run from code/pebble/.
set -e
cd "$(dirname "$0")"
docker run --rm -d --name academy-crypto-dns --network host \
    ghcr.io/letsencrypt/pebble-challtestsrv:latest \
    -defaultIPv4 127.0.0.1 -defaultIPv6 "" \
    -http01 "" -https01 "" -tlsalpn01 "" -doh ""
docker run --rm -d --name academy-crypto-pebble --network host \
    -e PEBBLE_VA_NOSLEEP=1 \
    -v "$PWD/pebble-config.json:/test/config/pebble-config.json:ro" \
    ghcr.io/letsencrypt/pebble:2.8.0 \
    -config /test/config/pebble-config.json -dnsserver 127.0.0.1:8053
# pebble's throwaway test root, for SSL_CERT_FILE
curl -fsS -o pebble-root.pem \
    https://raw.githubusercontent.com/letsencrypt/pebble/main/test/certs/pebble.minica.pem

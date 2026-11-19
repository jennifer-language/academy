#!/bin/sh
# run-offline.sh - run a program against fakeapi.j instead of TMDB and Steam.
#   ./run-offline.sh jennifer run tonight.j
# It makes a throwaway certificate authority and a certificate for the three
# API hosts, then starts a private user, mount and network namespace (pasta,
# from the passt package) where /etc/hosts sends those hosts to 127.0.0.1 and
# SSL_CERT_FILE trusts only that authority. Port 18096 (the local Jellyfin)
# is forwarded into the namespace. The decks run unchanged; nothing reaches
# the real services.
set -eu
cd "$(dirname "$0")"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
HOSTS="api.themoviedb.org api.steampowered.com store.steampowered.com"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=talk test CA" \
  -keyout "$T/ca.key" -out "$T/ca.pem" 2>/dev/null
SAN=$(for h in $HOSTS; do printf 'DNS:%s,' "$h"; done | sed 's/,$//')
openssl req -newkey rsa:2048 -nodes -subj "/CN=fakeapi" -keyout "$T/key.pem" \
  -out "$T/req.csr" 2>/dev/null
printf 'subjectAltName=%s\n' "$SAN" > "$T/ext"
openssl x509 -req -in "$T/req.csr" -CA "$T/ca.pem" -CAkey "$T/ca.key" \
  -CAcreateserial -days 1 -extfile "$T/ext" -out "$T/cert.pem" 2>/dev/null
{ echo "127.0.0.1 localhost"; for h in $HOSTS; do echo "127.0.0.1 $h"; done; } > "$T/hosts"
echo "hosts: files dns" > "$T/nsswitch.conf"

export SSL_CERT_FILE="$T/ca.pem" T
exec pasta --config-net -T 18096 -- unshare -m sh -c '
  mount --bind "$T/hosts" /etc/hosts
  mount --bind "$T/nsswitch.conf" /etc/nsswitch.conf
  jennifer run fakeapi.j "$T/cert.pem" "$T/key.pem" 2>"$T/fakeapi.log" &
  sleep 1
  "$@"; rc=$?
  kill $! 2>/dev/null
  cat "$T/fakeapi.log" >&2
  exit $rc' sh "$@"

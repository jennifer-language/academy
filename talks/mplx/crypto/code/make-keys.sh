#!/bin/sh
# Write the two placeholder JWT keys keys.j reads, into keys/.
# The newer one is left readable by others on purpose: keys.j refuses it,
# then fixes the mode and reads it.
set -e
cd "$(dirname "$0")"
mkdir -p keys
printf 'PLACEHOLDER-key-2026-10-xxxxxxxxxxxx' > keys/jwt-2026-10
printf 'PLACEHOLDER-key-2026-11-xxxxxxxxxxxx' > keys/jwt-2026-11
chmod 600 keys/jwt-2026-10
chmod 644 keys/jwt-2026-11

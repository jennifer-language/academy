#!/bin/sh
# The nightly report against the fake homelab on 127.0.0.1:28771, then the
# same with the Docker host unreachable (nothing on 127.0.0.1:2375).
# The fake's request log goes to fake.log; the fake is stopped at the end.
cd "$(dirname "$0")"
jennifer run fake.j 28771 > fake.log 2>&1 &
fake=$!
sleep 1
F=http://127.0.0.1:28771
export PVE_URL=$F PVE_TOKEN_ID='report@pve!nightly' \
    PVE_SECRET=00000000-0000-0000-0000-000000000000 \
    DSM_URL=$F DSM_USER=report DSM_PASSWORD=placeholder \
    UNRAID_URL=$F/graphql UNRAID_KEY=placeholder-key \
    FRIGATE_URL=$F FRIGATE_USER=report FRIGATE_PASSWORD=placeholder \
    DOCKER_URL=tcp://127.0.0.1:28771
jennifer run nightly.j; echo "exit $?"
echo "--- with the Docker host down:"
DOCKER_URL=tcp://127.0.0.1:2375 jennifer run nightly.j | grep '^FAIL'
kill $fake

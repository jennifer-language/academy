#!/bin/sh
# The demo of the slides against the fake routers: dry run, the rollback
# on branch-09 with MT_VERBOSE, then two real runs. The fake's log of every
# command goes to fake.log; the fake is stopped at the end.
cd "$(dirname "$0")"
export MT_USER=iac MT_PASSWORD=lab-only MT_BACKUP_PASSWORD=placeholder-backup-pw
jennifer run fakerouter.j fake/branch-07.toml fake/branch-08.toml \
    fake/branch-09.toml > fake.log 2>&1 &
fake=$!
sleep 1
echo '$ jennifer run converge.j --dry-run'
jennifer run converge.j --dry-run
echo '$ MT_VERBOSE=1 jennifer run converge.j devices/branch-09.toml'
MT_VERBOSE=1 jennifer run converge.j devices/branch-09.toml
echo '$ jennifer run converge.j; echo "exit $?"'
jennifer run converge.j; echo "exit $?"
echo '$ jennifer run converge.j'
jennifer run converge.j
kill $fake

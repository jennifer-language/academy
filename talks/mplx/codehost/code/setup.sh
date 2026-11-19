#!/bin/sh
# Prepare tempo on the local Forgejo and GitLab: the repository on each,
# a local checkout in work/tempo with tags 1.2.0 and 1.3.0, pushed
# (main only), and the release files in work/dist.
# Needs FORGEJO_TOKEN (write:repository, write:issue, write:user) and
# GITLAB_TOKEN (api), both of the user relbot.
set -eu
FJ=http://127.0.0.1:13300
GL=http://127.0.0.1:18929
json="Content-Type: application/json"
curl -fsS -o /dev/null -X POST -H "Authorization: token $FORGEJO_TOKEN" \
    -H "$json" "$FJ/api/v1/user/repos" \
    -d '{"name":"tempo","default_branch":"main"}'
curl -fsS -o /dev/null -X POST -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    -H "$json" "$GL/api/v4/projects" \
    -d '{"name":"tempo","path":"tempo","visibility":"public"}'

rm -rf work
mkdir -p work/dist
git init -q -b main work/tempo
cd work/tempo
export GIT_AUTHOR_NAME=relbot GIT_AUTHOR_EMAIL=relbot@example.invalid
export GIT_COMMITTER_NAME=relbot GIT_COMMITTER_EMAIL=relbot@example.invalid
step() {
    echo "$2" >> README.md
    git add README.md
    GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" git commit -qm "$2"
}
step 2026-10-01T10:00:00Z "tempo: add durations"
step 2026-10-02T10:00:00Z "parse: accept 1h30m"
GIT_COMMITTER_DATE=2026-10-02T11:00:00Z git tag -a 1.2.0 -m "Release 1.2.0"
step 2026-11-10T10:00:00Z "parse: keep seconds (#7)"
step 2026-11-12T10:00:00Z "format: print 0s for zero"
step 2026-11-14T10:00:00Z "docs: the --sum flag (#9)"
GIT_COMMITTER_DATE=2026-11-14T11:00:00Z git tag -a 1.3.0 -m "Release 1.3.0"
git push -q "http://relbot:$FORGEJO_TOKEN@127.0.0.1:13300/relbot/tempo.git" main
git push -q "http://oauth2:$GITLAB_TOKEN@127.0.0.1:18929/relbot/tempo.git" main
git archive --prefix tempo-1.3.0/ -o ../dist/tempo-1.3.0.tar.gz 1.3.0
cd ../dist
sha256sum tempo-1.3.0.tar.gz > SHA256SUMS
git -C ../tempo rev-parse 1.3.0^{commit}

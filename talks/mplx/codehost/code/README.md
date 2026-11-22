# Code for "One API over GitHub, GitLab and Forgejo"

The programs behind the slides, for Jennifer 0.27.0 and the released decks
`@deckyard/codehost` 0.3.0 (with github 0.3.0, gitlab 0.4.0, forgejo 0.4.0)
and `@deckyard/git` 0.2.0. Everything runs against local throwaway servers:
Forgejo and GitLab CE in docker, and a GitHub stand-in written in Jennifer.
No real forge account is used, except one anonymous read in `ratelimit.j`.

Run every command from this folder. `jvc install` and `setup.sh` create
`vendor/` and `work/`; neither belongs in the repository.

## Setup

```sh
jvc install                                   # vendor/ from deck.toml

# Forgejo on 127.0.0.1:13300
docker run -d --name academy-forge-forgejo -p 127.0.0.1:13300:3000 \
  -e FORGEJO__security__INSTALL_LOCK=true \
  -e FORGEJO__database__DB_TYPE=sqlite3 \
  -e FORGEJO__server__ROOT_URL=http://127.0.0.1:13300/ \
  codeberg.org/forgejo/forgejo:13
docker exec -u git academy-forge-forgejo forgejo admin user create --admin \
  --username relbot --password 'CHANGE-ME-long-password' \
  --email relbot@example.invalid --must-change-password=false
docker exec -u git academy-forge-forgejo forgejo admin user \
  generate-access-token --username relbot --token-name rw --raw \
  --scopes write:repository,write:issue,write:user
docker exec -u git academy-forge-forgejo forgejo admin user \
  generate-access-token --username relbot --token-name ro --raw \
  --scopes read:repository

# GitLab CE on 127.0.0.1:18929 (needs about 4 GB of RAM, starts in minutes)
docker run -d --name academy-forge-gitlab --shm-size 256m \
  -p 127.0.0.1:18929:18929 \
  -e GITLAB_ROOT_PASSWORD='CHANGE-ME-random-password' \
  -e GITLAB_OMNIBUS_CONFIG="external_url 'http://127.0.0.1:18929'; prometheus_monitoring['enable']=false; registry['enable']=false" \
  gitlab/gitlab-ce:latest
```

In GitLab, sign in as root, create the user `relbot` and, as `relbot`, a
personal access token with scope `api` and one with `read_api`.

```sh
jennifer run ghfake.j 127.0.0.1:18080 &       # the GitHub stand-in
export GITHUB_TOKEN=placeholder-github-token  # the stand-in checks none
export FORGEJO_TOKEN=<the rw token> GITLAB_TOKEN=<the api token>
./setup.sh                                    # prints the 1.3.0 commit
jennifer run seed.j                           # two issues on each forge
```

`forges.toml` lists the three forges; set `FORGES` to use another file.

## Programs, in the order of the slides

| File | Slides | Run |
| --- | --- | --- |
| `forges.j`, `forges.toml` | A Forge from configuration | imported by the others |
| `repos.j` | One loop, three forges | `jennifer run repos.j` |
| `pulls.j`, `pulls.toml` | Change requests | `FORGES=pulls.toml jennifer run pulls.j` |
| `show.j` | Releases with assets | `jennifer run show.j` (after the release) |
| `ci.j` | A red gate, A green run | `jennifer run ci.j <sha> ci/check pending` |
| `release.j` | The release script to A green run | `jennifer run release.j work/tempo 1.3.0 work/dist/tempo-1.3.0.tar.gz work/dist/SHA256SUMS` |
| `labels.j` | Sync labels | `jennifer run labels.j` |
| `errors.j` | Errors; Tokens and scopes | `jennifer run errors.j`, then again with the read-only tokens in `FORGEJO_TOKEN` and `GITLAB_TOKEN` |
| `ratelimit.j` | Paging and rate limits | `jennifer run ratelimit.j` (one anonymous call to api.github.com) |
| `plainhttp.j` | Plain http is an opt-in | `jennifer run plainhttp.j` (sends nothing; `git.lan` must not resolve) |
| `extras.j` | Beyond the common verbs | `jennifer run extras.j`; `--kick` starts CI, which tempo lacks |

Helpers: `ghfake.j` answers the GitHub REST paths these programs use, under
`/api/v3` and `/api/uploads` as a GitHub Enterprise Server does, from memory;
it is not GitHub. `setup.sh` creates the repositories and the local checkout.
`seed.j` opens the issues. `ci.j` reports a commit status as CI would.

## Cleanup

```sh
docker rm -f academy-forge-forgejo academy-forge-gitlab
kill %1                                       # the stand-in
rm -rf work vendor
```

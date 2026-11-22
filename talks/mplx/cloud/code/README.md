# Storing data in the cloud: the code

The programs behind the slides, for Jennifer 0.27.0. S3 and WebDAV use the
bundled `s3.j` and `webdav.j` modules; Koofr and Seafile use the
`@deckyard/koofr` and `@deckyard/seafile` decks listed in `deck.toml`, so run
`jvc install` once in this folder to fill `vendor/`. Run everything from this
folder after `. ./env.sh`, which sets the server URLs and the placeholder
credentials below.

## The servers, all on 127.0.0.1

- S3: MinIO (Bitnami image), buckets `backups` and `mirror`:
  `docker run --rm -d --name academy-cloud-minio -p 127.0.0.1:19000:9000 -e MINIO_ROOT_USER=academy -e MINIO_ROOT_PASSWORD=academy-secret-123 -e MINIO_DEFAULT_BUCKETS=backups,mirror bitnamilegacy/minio:2025.7.23`
- WebDAV: Apache httpd 2.4 with `mod_dav` on port 18081, user `alice`:
  `webdav/start.sh` (writes `webdav/htpasswd`, then starts the container with
  `webdav/httpd.conf`).
- Seafile: Seafile 12 (`seafileltd/seafile-mc:12.0-latest`, with MariaDB),
  set up with Seafile's Docker instructions and published on
  `127.0.0.1:18082`; the admin account is `SEAFILE_USER` /
  `SEAFILE_PASSWORD`.
- Koofr: Koofr is hosted, so `koofrfake.j` stands in for the few API
  endpoints the talk uses, in memory. It is not the real service.
  `jennifer run koofrfake.j 18083 &` (with `FAKE_BUSY=2` it answers the first
  two uploads with 429 and `Retry-After: 1`).

## The programs

- `s3basics.j`: put with metadata, list by prefix ("S3: keys, metadata and a
  listing"). Run: `jennifer run s3basics.j`
- `s3more.j`: a missing key as a status, copy, and a presigned link fetched
  without credentials ("S3: errors are values, links are signed").
  Run: `jennifer run s3more.j`
- `multipart.j`: a multipart upload with a checked ETag per part, aborted on
  failure ("S3: a large file in parts", "What the bucket got"). Make a test
  file first: `head -c 12582912 /dev/urandom > big.bin`, then
  `jennifer run multipart.j big.bin`
- `dav.j`: mkcol, put, propfind, get ("WebDAV: HTTP verbs for a file tree").
  Run: `jennifer run dav.j`
- `davmatch.j`: write with `If-Match` so a concurrent change is not lost
  ("Never overwrite someone else's change"). Run: `jennifer run davmatch.j`
- `props.j`: set and read a dead property in the owncloud namespace ("Nextcloud
  and ownCloud are WebDAV servers"). Needs `/report.txt` on the server (put there
  by `backup.j docs`). Run: `jennifer run props.j`
- `daverr.j`: the WebDAV error struct and the statuses behind it ("Errors:
  one struct per backend", "The statuses you will meet").
  Run: `jennifer run daverr.j`
- `koofr1.j`: mounts, mkdir, put, list, a public link, a 409 on a second
  create ("Koofr: mounts, files and links"). Run: `jennifer run koofr1.j`
- `koofrretry.j`: `withRetries` against a busy server ("Retries: who does
  what"). Run the stand-in with `FAKE_BUSY=2`, then
  `jennifer run koofrretry.j`
- `sea.j`: login, a library, mkdir with parents, put, a share link
  ("Seafile: libraries, files and links"). Run: `jennifer run sea.j`
- `seaenc.j`: an encrypted library, locked and unlocked ("Seafile: encrypted
  libraries"). Needs `VAULT_PASSWORD` (set in `env.sh`).
  Run: `jennifer run seaenc.j`
- `large.j`: the response size caps of `webdav.j` and the Seafile deck, kind
  `"limit"` ("Large files and limits"). Needs a file bigger than 1 MiB, such
  as `big.bin` above. Run: `jennifer run large.j big.bin`
- `creds.j`: the decks refuse credentials over plain http to a non-loopback
  host ("Credentials"). Run: `jennifer run creds.j`
- `backup.j`: mirrors a folder to the `mirror` bucket and to WebDAV, sending
  only changed files, with a SHA-256 manifest ("Checksums: trust, but
  verify", "A backup job: mirror one folder to two backends", "Four runs, one
  outage"). `docs/` is the sample folder. Run: `jennifer run backup.j docs`

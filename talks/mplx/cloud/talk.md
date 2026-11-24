---
theme: nordic
ratio: 16:9
transition: slide
---

# Storing data in the cloud: S3, WebDAV, Koofr™ and Seafile™

![Jennifer](jennifer-logo.png)

Object storage, a file protocol and two file-sync services from one
Jennifer program, and a backup job that mirrors a folder to two of them.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
This talk puts files into four kinds of cloud storage from Jennifer: an S3
bucket with the bundled s3 module, a WebDAV server with the bundled webdav
module, and the file-sync services Koofr™ and Seafile™ with two Deckyard decks.
Every output is from a real run on a laptop: MinIO™ for S3, Apache™ httpd with
mod_dav for WebDAV, and the official Seafile 12 image. Koofr is a hosted
service, so its slides ran against a small stand-in server written in
Jennifer that answers the endpoints the deck calls; no request went to Koofr.
The code on the slides is cut from those programs: setup and printf lines are
left out, everything shown ran as it stands.
-->

---

## Three ways to keep files in the cloud

| | Object storage | WebDAV | File sync |
| --- | --- | --- | --- |
| Examples | S3, MinIO, R2, B2 | Nextcloud™, a NAS, Apache | Koofr, Seafile |
| You store | an object under a key | a file in a folder | a file in a library |
| Folders | none: `/` is part of the key | real collections | real folders |
| Sharing | presigned URLs | depends on the server | public and upload links |
| Extras | metadata, huge scale | properties, `If-Match` | history, trash, clients |

**Rule of thumb:** programs write to buckets, people work in sync
services, and WebDAV connects the two.

<!-- notes:
Object storage is a flat key-value store for blobs: there are no folders,
only keys that happen to contain slashes, and every write replaces a whole
object. It is cheap, scales without limit and suits backups, media and build
artefacts. WebDAV is HTTP with a few extra methods for a real folder tree;
almost every NAS and Nextcloud speak it. File-sync services add desktop and
phone clients, version history, a trash and sharing links. Choose by who
reads the data: a machine, a person, or both.
-->

---

## The setup

| Backend | In Jennifer 0.26.0 | For this talk, on 127.0.0.1 |
| --- | --- | --- |
| S3 | `import "s3.j"`, bundled | MinIO (Bitnami™ image) |
| WebDAV | `import "webdav.j"`, bundled | Apache httpd 2.4 with `mod_dav` |
| Koofr | `@deckyard/koofr` 0.3.0 | a stand-in written in Jennifer |
| Seafile | `@deckyard/seafile` 0.2.0 | Seafile 12.0.14, MariaDB™ |

```sh
jvc add @deckyard/koofr
jvc add @deckyard/seafile
jvc install                  # copies both into vendor/deckyard/
```

<!-- notes:
The two protocols are bundled modules, so they need no install. The two
services are community decks from Deckyard; jvc copies their sources into
vendor and the programs import them as "@deckyard/koofr/". Both decks need
the net capability and nothing else. MinIO's own image is no longer on Docker™
Hub, so the S3 server here is Bitnami's MinIO image. All four servers were
bound to the loopback address, and every credential on these slides is a
placeholder.
-->

---

## S3: keys, metadata and a listing

```jennifer excerpt
def r as http.Response init s3.put($c, BUCKET, "notes/todo.txt",
    "buy milk\n");
$r = s3.putWith($c, BUCKET, "photos/2026/cat.txt", "meow\n",
    "text/plain", {"owner": "alice", "source": "phone"});
$r = s3.head($c, BUCKET, "photos/2026/cat.txt");
for (def k in s3.objectKeys(s3.listObjects($c, BUCKET).body)) {
    if (strings.startsWith($k, "photos/")) {       # no prefix param
        io.printf("  %s\n", $k);
```

```text
put 200, ETag "8bc0d2e9ed325bc04c190eb7b9554293"
head 200 text/plain owner=alice
  photos/2026/cat.txt
  photos/2026/dog.txt
```

<!-- notes:
The client comes from s3.connect with the endpoint, the region and the key
pair, all read from the environment. putWith signs a content type and
metadata, which S3 stores as x-amz-meta headers and head returns. The
listing comes back as ListObjectsV2 XML; objectKeys pulls out the keys. The
0.26.0 module has no prefix or delimiter parameter, so the program filters
the keys itself, and isTruncated with listObjectsFrom pages past a thousand
keys. A small object's ETag is the MD5 of its bytes. The printf lines between
the calls are left out of the excerpt.
-->

---

## S3: errors are values, links are signed

```jennifer excerpt
def r as http.Response init s3.get($c, BUCKET, "notes/missing.txt");
if ($r.status != 200) {                   # a value, not an exception
    def e as s3.S3Error init s3.errorOf($r);
    io.printf("%s\n", $e.message);       # also .status, .code
}
def u as string init s3.presign($c, "GET", BUCKET, "notes/todo.txt",
    600);                                 # valid for ten minutes
$r = http.get($u, {});                  # no key, no secret
```

```text
s3: HTTP 404: NoSuchKey: The specified key does not exist.
http://127.0.0.1:19000/backups/notes/todo.txt?X-Amz-Algorithm=AWS4-...
presigned GET: 200 buy milk
copy 200, delete 204
```

<!-- notes:
The object calls return the http.Response and never throw for a 4xx or 5xx:
check the status, and errorOf turns S3's XML error into an S3Error struct
with the status, S3's code such as NoSuchKey or SlowDown, and the request id.
presign builds a URL that grants one method on one key for one to 604800
seconds; it sends nothing. The URL is cut here; anyone who has it may use it
until it expires. copy is server side, and copy plus delete is how a rename
looks in object storage.
-->

---

## S3: a large file in parts

```jennifer excerpt
try {                       # $id from s3.createMultipartUpload
    while (not fs.eof($f)) {
        def part as bytes init fs.readBytes($f, PART);   # 5 MiB
        def n as int init len($etags) + 1;
        def tag as string init s3.uploadPart($c, BUCKET, $key, $id, $n,
            $part);
        if ($tag != md5($part)) {          # a part's ETag is its MD5
            throw Error{kind: "s3", message: "part {$n}: ETag {$tag}"};
        }
        $etags[] = $tag;
    }                              # then completeMultipartUpload
} catch (e) {
    s3.abortMultipartUpload($c, BUCKET, $key, $id);   # no orphan parts
```

<!-- notes:
One PUT holds the whole body in memory and stops at about 5 GB, so a large
file goes up in parts: create the upload, send numbered parts of at least
5 MiB except the last, then complete it with the ETags in order. The file is
read from a handle five MiB at a time, so memory stays flat. Comparing each
ETag with the part's MD5 is a checksum, and in 0.26.0 it is also the guard
against a known bug: uploadPart ignores the HTTP status, so a refused part
returns an empty ETag. On any failure, abort, or the parts cost money.
-->

---

## What the bucket got

```text
$ jennifer run multipart.j big.bin        # 12 MiB of random bytes
part 1: 5242880 bytes, "3444246a098524ccc36de44625223b02"
part 2: 5242880 bytes, "e3ca769140c11b8a1178225410618812"
part 3: 2097152 bytes, "8ddd0f15a40f66ae3d6681b7f361ced5"
complete: "f3c2ccff0eaf19c1b55423a8587bb578-3"
```

- The final ETag is **not** the file's MD5: it is the MD5 of the part
  MD5s, then `-3` for three parts
- Parts: 5 MiB to 5 GiB, at most 10,000; any order, completed in order
- Keep your own checksum of the whole file (see the backup job)

<!-- notes:
The three part ETags match what md5sum prints for each slice of the file,
so every part arrived intact. The ETag of the completed object ends in -3,
the number of parts, and is a hash of hashes: comparing it with md5sum of the
file fails, which surprises people the first time. Store a checksum you
compute yourself, as metadata or in a manifest. An upload that is neither
completed nor aborted keeps its parts on the server; a lifecycle rule on the
bucket cleans up after crashed jobs.
-->

---

## One module, many providers

| Store | endpoint | region |
| --- | --- | --- |
| AWS™ S3 | `https://s3.<region>.amazonaws.com` | the bucket's region |
| MinIO | `http://host:9000` | `us-east-1` or as configured |
| Cloudflare™ R2 | `https://<account>.r2.cloudflarestorage.com` | `auto` |
| Backblaze™ B2 | `https://s3.<region>.backblazeb2.com` | the bucket's region |

- Path-style addressing, Signature Version 4, a 30 s timeout per request
- Not in the module: creating buckets, ACLs, policies, prefix listings
- The endpoint is `scheme://host[:port]`, **without** a trailing slash

<!-- notes:
The table is from the module's documentation; only the MinIO row ran for
this talk. Create the bucket once with the provider's console or tool: the
module works on objects. Write the endpoint without a trailing slash: in
0.26.0 a slash there makes the client sign a different path than it sends,
and every request fails with SignatureDoesNotMatch; the next release fixes
that. The responses are not capped either, so a huge listing is held in
memory. Set Client.timeout to change the 30 second bound.
-->

---

## WebDAV: HTTP verbs for a file tree

```jennifer excerpt
def c as webdav.Client init webdav.connect(os.getEnv("DAV_URL"));
...                                     # withBasicAuth, see below
webdav.mkdirAll($c, "/Backups/2026/11");                 # MKCOL x3
webdav.put($c, "/Backups/2026/11/notes.txt", $text);     # PUT
webdav.copy($c, "/Backups/2026/11/notes.txt", "/Backups/copy.txt",
    false);                                              # COPY
webdav.move($c, "/Backups/copy.txt", "/Backups/old.txt", false);
for (def r in webdav.readDir($c, "/Backups")) {          # PROPFIND
    io.printf("%s %t %d %s\n", $r.path, $r.isDir, $r.size, $r.etag);
}
```

```text
/Backups/2026 true 0 W/"4-660a094cbc076"
/Backups/old.txt false 9 W/"9-660a094cbdbce"
```

<!-- notes:
Each call is one request, or one per level for mkdirAll. readDir sends
PROPFIND with depth 1 and returns Resource values with path, size, modified
time, ETag and content type; walk goes deeper one level at a time, because
many servers refuse an infinite depth. The last argument of copy and move is
overwrite: false sends Overwrite: F. Apache marks an ETag weak, W/, while the
file changed within the last second. LOCK and UNLOCK are not in the module;
a locked file shows up as status 423.
-->

---

## Never overwrite someone else's change

```jennifer excerpt
func save(c as webdav.Client, p as string, s as string, t as string) {
    def o as webdav.PutOptions;
    $o.ifMatch = $t;                      # only if nobody changed it
    webdav.putWith($c, $p, encoding.encode("utf-8", $s), $o);
}
def mine as string init webdav.stat($c, $p).etag;
save($c, $p, "buy milk and bread\n", $mine);      # another writer
try {
    save($c, $p, "buy milk and eggs\n", $mine);   # my stale copy
```

```text
read     "9-660a094cbcc2e"
changed  W/"13-660a094ebac70"
refused  412 PUT /Backups/2026/11/notes.txt
```

<!-- notes:
This is optimistic locking: read the ETag, and write with If-Match. If the
file changed in between, the server answers 412 and the module throws a
WebdavError with status 412 instead of overwriting. The program then reads
again and merges. ifMatch needs a strong tag; the module refuses a weak W/
one, which can never match. onlyIfNew sends If-None-Match: * and refuses to
replace an existing file. The catch, left out here, checks the kind and
prints the error's status, method and path fields.
-->

---

## Nextcloud and ownCloud are WebDAV servers

- URL: `https://cloud.example.com/remote.php/dav/files/<user>`
- Sign in with an **app password** (Settings, Security), never the login
- Extra properties by Clark name: `{http://owncloud.org/ns}fileid`

```jennifer excerpt
def const FAV as string init "\{http://owncloud.org/ns\}favorite";
webdav.proppatch($c, "/report.txt", {FAV: "1"}, []);    # PROPPATCH
def size as string init webdav.clark(webdav.DAV_NS, "getcontentlength");
for (def r in webdav.propfind($c, "/report.txt", 0, [FAV, $size])) {
    io.printf("%s favorite=%s size=%d\n", $r.path, $r.props[FAV], $r.size);
}
```

```text
/report.txt favorite=1 size=17
```

<!-- notes:
Nextcloud and ownCloud™ serve every user's files below remote.php/dav, and
favourites, file ids and tags are WebDAV properties in the owncloud
namespace. The output here is from Apache, which stores any property you set
as a dead property, so the same two calls ran; on Nextcloud they star the
file in the web interface. An app password can be revoked alone and cannot
change the account. With two-factor login it is the only password a script
can use.
-->

---

## Koofr: mounts, files and links

```jennifer excerpt
def c as koofr.Client init koofr.client(os.getEnv("KOOFR_URL"));
$c = koofr.withAppPassword($c, os.getEnv("KOOFR_EMAIL"),
    os.getEnv("KOOFR_PASSWORD"));
def m as koofr.Mount init koofr.primaryMount($c);
koofr.mkdirAll($c, $m.id, "/Backups/2026/11");
def opts as koofr.PutOptions;                     # zero value: refuse
def f as koofr.File init koofr.put($c, $m.id,
    "/Backups/2026/11/notes.txt", $data, $opts);
def l as koofr.Link init koofr.createLink($c, $m.id, $f.path);
```

```text
mount Koofr (hosted), id m-1
put /Backups/2026/11/notes.txt, 9 bytes
link https://k00.fr/l-1
409 AlreadyExists
```

<!-- notes:
Koofr addresses files by a mount id and a path: the primary mount is your
own storage, others are connected devices and folders shared with you. The
zero PutOptions refuse to replace a file, so the second put throws a
KoofrError with status 409 and code AlreadyExists, the last line; overwrite,
autorename and overwriteIfHash change that. createLink makes a public link, createReceiver
an upload link. This ran against the stand-in, which answers the deck's
endpoints with invented ids and links; it never contacted Koofr.
-->

---

## Seafile: libraries, files and links

```jennifer excerpt
def token as string init seafile.login($c, os.getEnv("SEAFILE_USER"),
    os.getEnv("SEAFILE_PASSWORD"), "");          # "" = no 2FA code
$c = seafile.withRetries(seafile.withToken($c, $token), 3);
def l as seafile.Library init seafile.createLibrary($c, "Backups", "");
seafile.mkdir($c, $l.id, "/2026/11", true);      # with parents
def e as seafile.Entry init seafile.put($c, $l.id,
    "/2026/11/notes.txt", $data, true);          # replace if there
def s as seafile.ShareLink init seafile.createShareLink($c, $l.id,
    $e.path, $o);
def u as seafile.UploadLink init seafile.createUploadLink($c, $l.id,
    "/2026", "", 0);                             # open, no expiry
```

```text
share  http://127.0.0.1:18082/f/32f60e01fa014b979340/
upload http://127.0.0.1:18082/u/d/a4e4838287d74f0988be/
```

<!-- notes:
A library is Seafile's unit of sync, sharing and encryption, addressed by its
UUID. login trades the password for an account token once; keep the token,
not the password. Transfers take two steps: the deck asks the API for an
upload or download link, then sends the bytes to the file server under
/seafhttp, which carries its own token, so no Authorization header goes there.
The share link expires after seven days, set in the ShareLinkOptions $o.
put with replace false stores a second copy as notes (1).txt instead. This
ran against the official Seafile 12 image, version 12.0.14.
-->

---

## Seafile: encrypted libraries

```jennifer excerpt
def v as seafile.Library init seafile.createLibrary($c, "Vault", $secret);
unlock($c, $v.id, "not-the-password");
unlock($c, $v.id, $secret);
seafile.put($c, $v.id, "/secret.txt", $pin, true);
```

```text
Vault encrypted=true
decrypt: 400 seafile: POST /api2/repos/5711fbd7-4942-4ae5-922f-
  f2198d3282ea/: HTTP 400: Incorrect password
decrypt: ok
get: pin 0000
```

- The files are encrypted at rest; the **server** decrypts through the API
- Real end-to-end: the desktop client, which decrypts locally

<!-- notes:
createLibrary with a password makes an encrypted library; unlock is a small
helper that calls seafile.decrypt in a try and prints the result. Its blocks are
stored encrypted, so a stolen disk or backup of the server reveals nothing.
But the Web API cannot read them until decrypt sends the password to the
server, which keeps the key in memory for a while; creating the library also
unlocks it for a time. So the server operator is trusted. A wrong password is
a SeafileError with status 400. The line of output is wrapped to fit, and the
PIN is a placeholder.
-->

---

## Errors: one struct per backend

| | S3 | WebDAV | Koofr | Seafile |
| --- | --- | --- | --- | --- |
| Refused | returns the response | throws | throws | throws |
| Kind | `s3` (`errorOf`) | `webdav` | `koofr` | `seafile` |
| Struct | `S3Error` | `WebdavError` | `KoofrError` | `SeafileError` |
| Fields | `status code requestId` | `status method path member` | `status code` | `status` |

Shared by all: `net` (a `net.NetError`), `limit`, `timeout`, `closed`.
**Match the kind, assign to the struct, then read its fields.**

<!-- notes:
Every library follows the same rule: a refused request is one struct per
backend, with the HTTP status as a field, and the generic kinds go through
unchanged: a socket failure is the interpreter's net.NetError, a reached cap
is limit, a server that stops answering is timeout. S3 is the odd one out:
its object calls return the response, so check the status yourself. In a
catch, compare the kind first, then write def w as webdav.WebdavError init
$e; from then on the fields are typed and safe. Never parse the message.
-->

---

## The statuses you will meet

```text
stale: 412 PUT /Backups/2026/11/notes.txt
new: 412 PUT /Backups/2026/11/notes.txt
missing: 404 GET /nope.txt
parent: 409 PUT /no/dir/a.txt
mkdir: 405 MKCOL /Backups
auth: 401 PROPFIND /
```

| Status | Means | Do |
| --- | --- | --- |
| 404, 409 | missing file, or missing parent folder | create the parent, or skip |
| 412 | `If-Match` or `If-None-Match` failed | read again, merge, retry |
| 429, 5xx | too many requests, server trouble | wait and retry |
| 401, 403 | credentials, permissions | stop and alert a person |

<!-- notes:
These six lines are one WebDAV program against Apache, each case in its own
try, printing the error's status, method and path: a stale ifMatch, an
onlyIfNew on an existing file, a missing file, and so on. A PUT into a folder that does not exist is 409, not 404, and MKCOL of an
existing folder is 405. The other backends use the same numbers: S3's
NoSuchKey is a 404, Koofr's AlreadyExists a 409, and Seafile adds its own 440
for a locked file and 443 for a full quota. Only 429 and 5xx are worth a
retry; retrying a 401 just locks the account sooner.
-->

---

## Retries: who does what

- Koofr, Seafile: `withRetries(c, n)` retries GETs, never writes
- S3, WebDAV: no retries; your own loop decides

```jennifer excerpt
for (def attempt in 1..5) {       # $opts.overwrite: idempotent
    try {
        koofr.put($c, $m.id, "/notes.txt", $data, $opts);
        break;
    } catch (e) {
        ...                                 # KoofrError, 429 or 5xx?
        time.sleep(time.fromSeconds($attempt));
```

```text
HTTP 429, retry in 1 s
HTTP 429, retry in 2 s
stored after 3 attempt(s)
```

<!-- notes:
withRetries retries a GET answered 429 or 5xx, waiting longer each time and
at least as long as Retry-After says, at most 30 seconds. The decks retry
reads only, because a write that timed out may have
succeeded, and a second POST could create a second file. A put that replaces
the file with the same bytes is idempotent, so retrying it is safe, and the
program does it in its own loop: at most four tries, waiting longer each
time, only for 429 and 5xx, any other error thrown on. The Koofr stand-in
answered the first two uploads with 429 and Retry-After 1, as a busy server
would.
-->

---

## Large files and limits

| | Download cap | Large uploads |
| --- | --- | --- |
| S3 | none | multipart, 5 MiB parts |
| WebDAV | `get(c, p, maxBytes)`: 0 means 64 MiB | one PUT from `bytes` |
| Koofr | `get(..., maxBytes)`: 0 means 64 MiB | one POST from `bytes` |
| Seafile | `get(..., maxBytes)`: 0 means 64 MiB | `putResumable`, 8 MiB chunks |

```text
[limit] webdav: GET /big.bin: http: response body exceeds 1048576 bytes
/big.bin: 12582912 bytes in Backups
```

<!-- notes:
Every body is held in memory, so the decks and the webdav module cap a
download at 64 MiB unless you pass maxBytes, and a bigger file is an error of
kind limit, not an out-of-memory crash. A negative maxBytes lifts the cap;
do that only for files you trust. The first line asked for at most 1 MiB of a
12 MiB file; the second is putResumable sending it to Seafile in 4 MiB chunks. putResumable sends a file in chunks with Content-Range and can
resume after a broken connection; S3 reaches the same with multipart.
-->

---

## Checksums: trust, but verify

| | The server gives you | Is it the file's hash? |
| --- | --- | --- |
| S3 | `ETag` | MD5 for one PUT; not for multipart |
| WebDAV | `ETag` | no: Apache uses size and time |
| Koofr | `File.hash` | MD5 of the content |
| Seafile | `Entry.id` | an object id, not a hash of the bytes |

**So:** compute SHA-256 yourself, before the upload, and store it where
the file goes: S3 metadata, or a `SHA256SUMS` file beside the files.

<!-- notes:
An ETag tells you whether something changed, not what the bytes are. Only
some servers make it a content hash, and the rules change with encryption
and multipart uploads. Computing SHA-256 locally before the upload, with
hash.compute, gives you a value you can check anywhere, also after you move
to another provider. The backup job at the end stores it twice: as
x-amz-meta-sha256 on each object, and in a manifest that sha256sum -c can
check.
-->

---

## Credentials

- From the **environment** or a 0600 file, never in the code or the repo
- **App passwords** (Koofr, Nextcloud) and **tokens** (Seafile), one per job
- Least privilege: a Seafile **library API token**, read-only
- **https only**: the decks refuse credentials over `http://` to other hosts

```text
[koofr] koofr: credentials go over http:// only to a loopback host; use
  https:// or withPlainHttp, got "http://files.example.com"
token for Backups, permission r
[seafile] seafile: GET /api/v2.1/via-repo-token/upload-link/?path=%2F:
  HTTP 403: You do not have permission to access this folder.
```

<!-- notes:
The Koofr and Seafile decks throw before they connect when credentials would
cross the network in clear text; loopback is allowed for tests. The webdav
module in 0.26.0 does not refuse Basic auth over http yet, that comes in the
next release, so check the scheme yourself. createApiToken with permission r
gives a token for one library that can read but not write, as the 403 shows.
S3 never sends the secret, but use https anyway. Output lines are wrapped.
-->

---

## A backup job: mirror one folder to two backends

```jennifer excerpt
func mirror(t as Target, root as string,
    local as map of string to string) {
    def remote as map of string to string init readRemote($t);
    for (def rel in lists.sort(maps.keys($local))) {
        def want as string init $local[$rel];
        if (not maps.has($remote, $rel) or $remote[$rel] != $want) {
            send($t, $rel, fs.readBytes($root + "/" + $rel));
        }
    }
    ...                    # remove what is in $remote, not in $local
    def text as string init render($local);
    send($t, MANIFEST, encoding.encode("utf-8", $text)); # last
```

<!-- notes:
The job is about 170 lines. scan walks the folder and hashes every file with
SHA-256. Each target, an S3 bucket and a WebDAV folder, keeps a SHA256SUMS
file in the format sha256sum writes. The job reads it, uploads only files
whose hash differs, deletes what was removed locally, and writes the
manifest last, so a crash in the middle leaves the old manifest and the next
run sends the rest again. send is the retry loop from before, for 429, 5xx
and network errors.
-->

---

## Four runs, one outage

```text
$ jennifer run backup.j docs
s3: 3 sent, 0 removed, 0 unchanged
webdav: 3 sent, 0 removed, 0 unchanged
$ jennifer run backup.j docs          # one file changed, one deleted
s3: 1 sent, 1 removed, 1 unchanged
webdav: 1 sent, 1 removed, 1 unchanged
$ jennifer run backup.j docs          # the WebDAV server is stopped
s3: 1 sent, 0 removed, 1 unchanged
webdav: [net] net.connect: 127.0.0.1:18081: dial tcp 127.0.0.1:18081:
  connect: connection refused
exit 1
```

<!-- notes:
The first run sends everything. The second, after one report changed and one
invoice was deleted, sends one file and deletes one on both sides. A third
run without changes, not shown, sent nothing. Then the WebDAV container was
stopped: S3 still got the change, each target has its own try, and the exit
status 1 tells the timer that something failed. After the restart the next
run sent the one missing file to WebDAV, and sha256sum -c on the downloaded
manifest said OK for both files. The comments after the commands and the
exit status of the successful runs were added and left out for the slide.
-->

---

## Takeaways and read more

- Buckets for programs, sync services for people, WebDAV in between
- Check S3's status; match the other three by **kind**, then read fields
- Retry 429 and 5xx, and only writes that are idempotent
- Your own SHA-256, credentials from the environment, https only
- [s3 module](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/s3.md),
  [webdav module](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/webdav.md),
  [deck-koofr](https://registry.jennifer-lang.dev/deck/deckyard/koofr),
  [deck-seafile](https://registry.jennifer-lang.dev/deck/deckyard/seafile)
- [The alerting talk](https://academy.jennifer-lang.dev/talks/mplx/alerting/),
  [the registry](https://registry.jennifer-lang.dev/)

Based on Jennifer 0.27.0, November 2026.

<!-- notes:
The four backends look different but fail alike, which is why one backup job
can serve two of them with a few lines per backend. Start with the question
of who reads the data, keep a checksum you computed yourself, and let the
job tell you when it failed: the alerting talk in this academy shows how to
send that message. The next Jennifer release tightens the s3 and webdav
modules; the known gaps of 0.26.0 are in the notes of the slides above.
-->

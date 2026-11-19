---
theme: carbon
mode: dark
ratio: 16:9
transition: slide
---

# Packaging a Jennifer app with Docker

![Jennifer](jennifer-logo.png)

From a working directory to an image that is small, runs as an
unprivileged user, carries no secrets, says when it is healthy and stops
cleanly.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
We package Shelf, the book club reading list from the talk "A web app in
Jennifer from scratch": a Jennifer web app with a MariaDB database. You do not
need to have seen that talk; all that matters here is that it is a few .j
files, a CSS file and a handbook in Markdown, configured through environment
variables. Every output on these slides is from a real build and run with
Docker on Linux.
-->

---

## The official interpreter images

| Tag | Base | Size | Use |
| --- | --- | --- | --- |
| `jennifer:0.26.0` | Debian trixie-slim | 168 MB | default; shell, apt, `jvc` |
| `jennifer:0.26.0-alpine` | Alpine | 60 MB | small, still a build base |
| `jennifer:0.26.0-static` | distroless | 51 MB | no shell: runtime only |
| `jennifer:dev` | Debian | ~170 MB | every push to `main` |

All under `ghcr.io/jennifer-language/`, for amd64 and arm64.
`ENTRYPOINT ["jennifer"]`, `WORKDIR /work`, a non-root user.

<!-- notes:
The interpreter image is published for every release. The slim variant is
the default and the most compatible: it has a shell and apt, CA certificates
for TLS, and jvc for decks. Alpine is the small one you can still build on.
Static is distroless: the interpreter, the modules and nothing else, about
a third of the size on disk. The tags :latest, :0.26 and :alpine float; a
deployment should pin the exact release, so the interpreter changes only
when you change the line that names it.
-->

---

## Try it before writing a Dockerfile

```sh
docker run --rm -p 127.0.0.1:8080:8080 -v "$PWD:/work:ro" \
    ghcr.io/jennifer-language/jennifer:0.26.0 run hello.j
```

```text
web.run($app, "127.0.0.1:8080");  ->  curl: (56) Recv failure:
                                       Connection reset by peer
web.run($app, ":8080");           ->  hello, Ada
```

Inside a container, listen on **all** interfaces, not on loopback.

<!-- notes:
Everything after the image name is a Jennifer subcommand, because the
entrypoint is the interpreter: run, test, lint, version, or repl, the
default. The current directory is mounted at /work, read-only. The trap shown
here costs everyone ten minutes once: a program that listens on 127.0.0.1
inside the container is unreachable through the published port, because the
port forward arrives on the container's own network interface. Publish on the
host's loopback instead, as the -p flag does.
-->

---

## Keep the build context small: an allowlist

```text
# .dockerignore: nothing is sent unless it is named here
*
!app.j
!addmember.j
!healthcheck.j
!src/
!public/
!docs/
!grimoire.toml
**/*_test.j
```

<!-- notes:
A .dockerignore that lists what to exclude fails open: the file nobody
thought of, a .env with real passwords, a database dump, a key, goes into the
build context and, with one careless COPY . line, into a layer that everyone
who pulls the image can read. An allowlist fails closed. It starts by
excluding everything, then lets in exactly what the Dockerfile copies. A new
file at the top of the repository stays out until someone names it here.
-->

---

## What actually reached the build

```text
$ ls -A
addmember.j   Dockerfile     .env           healthcheck.j  src
app.j         .dockerignore  .env.example   public
compose.yaml  docs           grimoire.toml  secrets

# the context, as COPY . /ctx/ saw it
./addmember.j            ./healthcheck.j
./app.j                  ./public/static/shelf.css
./docs/admin.md          ./src/store.j
./docs/index.md          ./src/views.j
./grimoire.toml
```

<!-- notes:
This is a test build whose only step copied the whole context, then listed
it. The .env file with the database password, the secrets directory, the
compose file, the Dockerfile itself and the test file src/store_test.j never
left the working directory. That is worth checking once whenever the
allowlist changes, because a mistake in it is invisible: the build still
succeeds, it just carries something it should not.
-->

---

## Stage one: the handbook, built by Grimoire

```dockerfile
# syntax=docker/dockerfile:1
ARG JENNIFER_IMAGE=ghcr.io/jennifer-language/jennifer:0.26.0
ARG GRIMOIRE_IMAGE=ghcr.io/jennifer-language/grimoire:0.5.0

FROM ${GRIMOIRE_IMAGE} AS docs
COPY grimoire.toml ./
COPY docs/ docs/
RUN ["jennifer", "run", "/opt/grimoire/bin/grimoire", "build"]
```

Only the rendered `site/` leaves this stage.

<!-- notes:
Grimoire, the documentation builder, has its own image on top of the
interpreter image, so building the handbook needs no local install. Its
working directory is /work, writable by its user, and grimoire.toml names
docs as the source; the HTML lands in site. RUN does not go through the
image's entrypoint, so it calls the launcher at /opt/grimoire/bin/grimoire
directly. Building the docs in the image means a fresh clone builds without a
generated directory that somebody forgot to commit.
-->

---

## Stage two: the app

```dockerfile
FROM ${JENNIFER_IMAGE}
COPY app.j addmember.j healthcheck.j /app/
COPY src/ /app/src/
COPY public/ /app/public/
COPY --from=docs --chown=root:root /work/site/ \
    /app/public/static/handbook/
WORKDIR /app
RUN ["jennifer", "lint", "app.j", "addmember.j", "healthcheck.j", \
     "src/store.j", "src/views.j"]
```

<!-- notes:
Nothing is compiled; the image is the interpreter plus our source. The
lint step makes a broken file fail the build instead of the first start.
Name every file: jennifer lint checks the files it is given, not the modules
they import, and the exec form has no shell to expand src/*.j. Any finding,
even a warning, exits 1 and stops the build. The handbook lands under
public/static, which the app already serves.
-->

---

## Who owns what

```text
$ docker run --rm --entrypoint sh shelf:latest \
    -c 'id; ls -l /app; touch /app/x'
uid=10001(jennifer) gid=999(jennifer) groups=999(jennifer)
total 16
-rw-r--r-- 1 root root  919 Nov 19 17:23 addmember.j
-rw-r--r-- 1 root root 6300 Nov 19 17:23 app.j
-rw-r--r-- 1 root root  451 Nov 19 17:23 healthcheck.j
drwxr-xr-x 1 root root   12 Nov 19 17:23 public
drwxr-xr-x 1 root root   28 Nov 19 17:23 src
touch: cannot touch '/app/x': Permission denied
```

`WORKDIR /app` *first* would have made `/app` itself `jennifer`'s.

<!-- notes:
The base image already switches to the user jennifer, uid 10001, so the app
never runs as root, and we keep it that way. The files are root's, so a
compromised process cannot rewrite the code it will run after the next
restart. The trap is in the last line: BuildKit creates a missing WORKDIR
owned by the current user, so with WORKDIR before the COPY lines the
directory belonged to jennifer, who could then delete and replace any file in
it. Copying first creates /app as root.
-->

---

## Configuration: the environment

```text
$ docker run --rm shelf:latest
shelf: set SHELF_DB_DSN, SHELF_CSRF_SECRET
$ echo $?
2
```

- Every setting is a variable: `SHELF_DB_DSN`, `SHELF_CSRF_SECRET`,
  `SHELF_ADDR`
- Each also reads `NAME_FILE`, a file holding the value
- Nothing environment-specific is baked into the image

<!-- notes:
One image runs in development, in CI and in production; only the environment
differs. The app checks its settings before it listens and exits with code 2
when one is missing, which a supervisor reports as a configuration error, not
a crash loop of mysterious 500s. The _FILE variants exist for secrets: the
value then sits in a mounted file instead of the environment, where docker
inspect and every child process could see it.
-->

---

## Secrets from files

```text
$ docker run ... -v "$PWD/secrets:/run/secrets:ro" \
    -e SHELF_DB_DSN_FILE=/run/secrets/db_dsn \
    -e SHELF_CSRF_SECRET_FILE=/run/secrets/csrf_secret shelf:latest
app.j: runtime error at /app/app.j:30:29: fs.readString:
/run/secrets/db_dsn: open /run/secrets/db_dsn: permission denied
```

The files were mode `0600`, owned by the host user. With `0644`:

```text
shelf: listening on [::]:8080
```

<!-- notes:
A bind mount keeps the host's owners and modes, and uid 10001 in the
container is nobody on the host, so a file only its owner may read cannot be
read by the app. Make it readable for the container's user, by mode or by
owning it as uid 10001, or use your orchestrator's secret store. Once it
starts, docker exec env shows no SHELF_DB_DSN at all: the password is only
in the file.
-->

---

## A health check without curl

```jennifer excerpt
try {
    def res as http.Response init http.requestWith("GET",
        "http://127.0.0.1:8080/healthz", {}, "", 2000, 4096);
    if ($res.status != 200) {
        io.printf("unhealthy: status %d\n", $res.status);
        exit 1;
    }
} catch (e) {
    io.printf("unhealthy: %s\n", $e.kind);
    exit 1;
}
```

<!-- notes:
The interpreter images have no curl or wget, and do not need one: the probe
is a short Jennifer program using the bundled http client, with a two
second timeout and a four kilobyte cap on the answer. Inside the container
the app is on loopback, so 127.0.0.1 is right here, unlike in the listen
address. /healthz deliberately does not query the database: a slow database
should not get every app container killed at the same moment.
-->

---

## HEALTHCHECK and what Docker makes of it

```dockerfile
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["jennifer", "run", "/app/healthcheck.j"]
CMD ["run", "app.j"]
```

```text
$ docker ps --format '{{.Names}}  {{.Image}}  {{.Status}}'
shelf-app-1  shelf:latest  Up 6 seconds (healthy)
```

<!-- notes:
Use the exec form, a JSON list, for HEALTHCHECK and CMD alike: it needs no
shell, so the same Dockerfile works on the distroless image later. CMD is
only the arguments, because the entrypoint is jennifer. Docker itself
restarts nothing when a check fails, but compose waits for it in depends_on,
Swarm replaces the task, and a proxy can stop routing to it. Without a check
a process that is alive but wedged looks fine forever.
-->

---

## docker stop, measured

| Program | `docker stop` | Exit code |
| --- | --- | --- |
| a plain `web.run` | 0.36 s | 2 |
| Shelf, catching SIGTERM | 0.54 s | 0 |

```text
shelf: listening on [::]:8080
shelf: shutting down
shelf: stopped
```

<!-- notes:
docker stop sends SIGTERM, and after ten seconds SIGKILL. The interpreter is
PID 1 in the container, and without a handler SIGTERM still ends it at once,
with exit code 2, in the middle of any request. Shelf catches the signal with
os.catchSignal, calls httpd.shutdown, which gives accepted requests up to
five seconds, closes its database pool and exits 0. Exit code 0 also keeps
monitoring from counting every deployment as a crash.
-->

---

## compose.yaml: the database

```yaml
services:
  db:
    image: mariadb:11.4
    environment:
      MARIADB_DATABASE: shelf
      MARIADB_USER: shelf
      MARIADB_PASSWORD: ${DB_PASSWORD:?set DB_PASSWORD in .env}
      MARIADB_RANDOM_ROOT_PASSWORD: "1"
    volumes: [db:/var/lib/mysql]
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 5s
```

<!-- notes:
The database keeps its data in a named volume, so rebuilding or replacing
containers loses nothing; the volume is declared at the end of the file
with volumes: db: and an empty value. The :? form makes compose refuse to
start when the variable is missing, instead of creating a user with an empty
password. Nobody needs the root password, so it is random. The MariaDB image
brings healthcheck.sh, which our app's depends_on waits for.
-->

---

## compose.yaml: the app

```yaml
  app:
    build: .
    image: shelf:latest
    depends_on:
      db: {condition: service_healthy}
    environment:
      SHELF_DB_DSN: "shelf:${DB_PASSWORD}@tcp(db:3306)/shelf"
      SHELF_CSRF_SECRET: ${CSRF_SECRET:?set CSRF_SECRET in .env}
    ports: ["127.0.0.1:8080:8080"]
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
```

<!-- notes:
The app starts only once the database answers, and the migrations run on its
first start. The port is published on the host's loopback only, for a
reverse proxy on the same host that terminates TLS; Shelf's cookies are
Secure, so it needs HTTPS in front. The last three lines are cheap
hardening: a read-only root filesystem, no Linux capabilities, no privilege
gain through setuid. Shelf ran with all three; it writes nothing to disk.
-->

---

## Running and operating it

```sh
cp .env.example .env    # DB_PASSWORD, CSRF_SECRET: openssl rand -hex 32
docker compose up -d --build
docker compose logs -f app
printf '%s\n' "$PW" | docker compose exec -T app \
    jennifer run addmember.j ada
docker compose up -d --build app     # after a change: rebuild, replace
```

```text
member 1: ada
```

<!-- notes:
.env sits next to compose.yaml, is read by compose on the host, and never
enters the image, thanks to the allowlist; keep it out of git too. Logs go to
standard output, so docker compose logs is the log. Administrative commands
run in the same image with docker compose exec; -T is needed when standard
input is a pipe, and the password never appears in the command line. Sessions
live in the app process, so a restart signs everyone out.
-->

---

## Smaller: the distroless image

```sh
docker build --build-arg \
    JENNIFER_IMAGE=ghcr.io/jennifer-language/jennifer:0.26.0-static \
    -t shelf:static .
```

```text
shelf:latest   168 MB      shelf:static   50.6 MB
$ docker run --rm --entrypoint sh shelf:static
docker: Error response from daemon: ... exec: "sh":
executable file not found in $PATH
```

Exec-form `RUN`, `HEALTHCHECK` and `CMD` only; the user is `nonroot`.

<!-- notes:
Because the Dockerfile uses only the exec form and never a shell, switching
the base is one build argument, and the result is a third of the size. It
ran the same: the health check passed, migrations and logins worked. What
you give up is a shell for debugging, apt, and jvc; the static user is
nonroot, uid 65532, instead of jennifer. And os.run has no programs to
start there, so an app that shells out to a tool stays on slim.
-->

---

## Decks, and what else to know

- **Decks:** run `jvc install` in a slim stage, copy `vendor/` into the
  runtime stage; `jvc` is not in the static image
- **Pin both images** to exact releases; move them on purpose
- **One replica** while sessions live in-process; Redis for more
- **Back up the volume**, not the container: `mariadb-dump`
- Images: [packaging/docker](https://github.com/jennifer-language/jennifer/tree/main/packaging/docker),
  Grimoire: [grimoire.jennifer-lang.dev](https://grimoire.jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
Shelf uses only bundled modules. An app with decks adds one stage on the slim
image that copies deck.toml and camcorder.lock and runs jvc install, and the
runtime stage copies the vendor directory from it; the image README shows
that two-stage build. The rest is the usual container hygiene: pinned
versions, state only in volumes, logs on standard output, a health check, and
a clean stop. The web-app talk explains the code inside the image.
-->

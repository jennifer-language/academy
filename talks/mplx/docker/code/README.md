# Packaging a Jennifer app with Docker: the code

Shelf, the book club reading list from the talk "A web app in Jennifer from
scratch", with everything that packages it: the Dockerfile, the
`.dockerignore` allowlist, `compose.yaml` and the handbook Grimoire builds.
The app files are the same as in that talk's `code/` (whose README explains
them); `src/store_test.j` is here to show that the allowlist keeps it out.
Built and run with Docker on Linux, Jennifer 0.26.0.

## Two files under other names

The academy's `code/` folder takes only listed file types, so two files
carry a `.txt` name here. Restore their real names before building:

    cp Dockerfile.txt Dockerfile
    cp dockerignore.txt .dockerignore

- `Dockerfile.txt` (`Dockerfile`): the two stages, the handbook built by
  Grimoire and the app on the interpreter image, with the lint step,
  `HEALTHCHECK` and `CMD` ("Stage one: the handbook, built by Grimoire",
  "Stage two: the app", "HEALTHCHECK and what Docker makes of it").
- `dockerignore.txt` (`.dockerignore`): the allowlist ("Keep the build
  context small: an allowlist", "What actually reached the build").

## The rest

- `hello.j`: the smallest web app, listening on `:8080` ("Try it before
  writing a Dockerfile"). Run:
  `docker run --rm -p 127.0.0.1:8080:8080 -v "$PWD:/work:ro" ghcr.io/jennifer-language/jennifer:0.26.0 run hello.j`,
  then `curl 'http://127.0.0.1:8080/hello?name=Ada'`. With
  `"127.0.0.1:8080"` instead, curl gets "Connection reset by peer".
- `app.j`, `addmember.j`, `healthcheck.j`, `src/`, `public/`: Shelf. The
  app reads `SHELF_DB_DSN`, `SHELF_CSRF_SECRET`, `SHELF_ADDR` or their
  `_FILE` variants ("Configuration: the environment", "Secrets from
  files"); `healthcheck.j` is the probe ("A health check without curl").
- `docs/`, `grimoire.toml`: the handbook, served at `/static/handbook/`.
- `compose.yaml`: MariaDB and the app ("compose.yaml: the database",
  "compose.yaml: the app").
- `.env.example`: the two values compose needs, as placeholders.

## Running it

    cp Dockerfile.txt Dockerfile; cp dockerignore.txt .dockerignore
    cp .env.example .env      # DB_PASSWORD, CSRF_SECRET: openssl rand -hex 32
    docker compose up -d --build
    docker ps --format '{{.Names}}  {{.Image}}  {{.Status}}'   # (healthy)
    printf '%s\n' "$PW" | docker compose exec -T app jennifer run addmember.j ada
    docker compose stop app; docker compose logs app   # shutting down, stopped
    docker compose down -v    # removes the containers and the volume

The app's cookies are `Secure`, so a browser signs in only through HTTPS,
from a reverse proxy in front of `127.0.0.1:8080`.

Other checks from the slides:

- Who owns what: `docker run --rm --entrypoint sh shelf:latest -c 'id; ls -l /app; touch /app/x'`
- Missing settings: `docker run --rm shelf:latest; echo $?` (prints 2)
- Secrets from files: put the DSN (`shelf:PASSWORD@tcp(db:3306)/shelf`)
  and the secret into `secrets/db_dsn` and `secrets/csrf_secret`, mode
  0644, and run on the compose network:
  `docker run --rm --network shelf_default -v "$PWD/secrets:/run/secrets:ro" -e SHELF_DB_DSN_FILE=/run/secrets/db_dsn -e SHELF_CSRF_SECRET_FILE=/run/secrets/csrf_secret shelf:latest`
  (mode 0600 gives "permission denied"). Keep `.env` and `secrets/` out of
  git; the allowlist keeps them out of the image.
- The distroless image:
  `docker build --build-arg JENNIFER_IMAGE=ghcr.io/jennifer-language/jennifer:0.26.0-static -t shelf:static .`

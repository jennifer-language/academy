# A web app in Jennifer from scratch: the code

Shelf, the book club reading list built on the slides, plus the smallest
web app from the start of the talk. Everything is bundled with the
interpreter (`web`, `sql`, `sqlmigrate`, `session`, `kvstore`, `tengine`,
`crypto`): no decks, no `vendor/`, nothing to install but Jennifer 0.26.0
and a MariaDB server. Run everything from this folder.

## A database for development and tests

A throwaway MariaDB in a container, data on a tmpfs ("Running the tests"):

    docker run -d --rm --name shelf-testdb -e MARIADB_ROOT_PASSWORD=test \
        -p 127.0.0.1:3399:3306 --tmpfs /var/lib/mysql mariadb:11.4

For the app, a database and a user in it (wait a few seconds after the
start first; `devpass` is a placeholder):

    docker exec shelf-testdb mariadb -uroot -ptest -e "CREATE DATABASE shelf;
        CREATE USER shelf@'%' IDENTIFIED BY 'devpass';
        GRANT ALL ON shelf.* TO shelf@'%';"
    export SHELF_DB_DSN='shelf:devpass@tcp(127.0.0.1:3399)/shelf'
    export SHELF_CSRF_SECRET=$(openssl rand -hex 32)

`docker stop shelf-testdb` removes it again.

## The programs

- `hello.j`: "The smallest web app". Run: `jennifer serve hello.j`, then
  `curl 'http://127.0.0.1:8080/hello?name=Ada'` (HEAD works too; `/nope`
  and a POST are 404).
- `app.j`: Shelf itself: configuration from the environment with `NAME_FILE`
  variants, the route table and middleware, login with a fresh session,
  forms, CSRF and the clean stop on SIGTERM or Ctrl-C ("Shelf's route
  table", "Configuration from the environment", "Sessions: a fresh id at
  every login", "Middleware: who may see what", "Forms: validate, write,
  redirect", "CSRF: a token in every form", "A clean stop"). It needs
  `SHELF_DB_DSN` and `SHELF_CSRF_SECRET` (at least 32 characters) and
  exits 2 without them; `SHELF_ADDR` (default `:8080`) sets the listen
  address. Its cookies are `Secure`, so on plain HTTP set
  `JENNIFER_WEB_INSECURE_COOKIES=1`.
  Run: `SHELF_ADDR=127.0.0.1:8080 JENNIFER_WEB_INSECURE_COOKIES=1 jennifer run app.j`
- `src/store.j`: the SQL: migrations, members with argon2id hashes, books
  ("The database: MariaDB through `sql`", "Migrations with `sqlmigrate`",
  "Reading and writing rows", "Passwords: argon2id").
- `src/views.j`: the templates, every user value through the `html` pipe
  ("Templates: `tengine`, escaped by hand").
- `src/store_test.j`: the tests, each in a database of its own ("Tests
  against a throwaway database", "A test", "Running the tests"). They skip
  without `SHELF_TEST_DSN`.
  Run: `SHELF_TEST_DSN='root:test@tcp(127.0.0.1:3399)/' jennifer test src/store_test.j`
- `addmember.j`: creates a member, the password from standard input
  ("Passwords: argon2id"). Run:
  `echo 'correct horse battery' | jennifer run addmember.j ada`
- `healthcheck.j`: probes `http://127.0.0.1:8080/healthz`, exit 0 or 1;
  for the container in the Docker talk. Run: `jennifer run healthcheck.j`
- `public/static/shelf.css`: the stylesheet, served under `/static/`.
- `curl-session.sh`: the curl session behind "What the server answered",
  against a running app with member `ada` and no books yet.
  Run: `./curl-session.sh`

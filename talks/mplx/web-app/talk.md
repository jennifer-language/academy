---
theme: meridian
ratio: 16:9
transition: slide
---

# A web app in Jennifer from scratch

![Jennifer](jennifer-logo.png)

Routes, forms, a database, logins, templates and CSRF protection, with
nothing but the modules that ship with the interpreter.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
We build Shelf, a reading list for a book club: members sign in, add books,
and mark them as read. It is small on purpose, about 360 lines of Jennifer in
three files, but it has every part a real web application needs, and each one
is done the safe way. Every output on these slides comes from a real run
against MariaDB 11.4 in a container. The companion talk packages the same app
with Docker.
-->

---

## What we build, and with what

```text
app.j            config, middleware, handlers, routes, serving
src/store.j      SQL: migrations, members, books
src/views.j      HTML templates
src/store_test.j tests against a throwaway database
addmember.j      a CLI to create a member
healthcheck.j    probes /healthz, for containers
public/static/   CSS
```

All bundled: `web`, `sql`, `sqlmigrate`, `session`, `kvstore`, `tengine`,
`crypto`. No decks, no `vendor/`.

<!-- notes:
Everything here is either a system library, switched on with use, or a
module that ships with Jennifer, brought in with import "web.j" and similar.
So there is no deck.toml and nothing to install besides the interpreter and a
database. The split is the classic one: the entry program owns the state and
the routes, store.j owns the SQL, views.j owns the markup. Both modules are
plain functions; they hold no mutable state of their own.
-->

---

## The smallest web app

```jennifer
import "web.j" as web;
func hello(ctx as web.Context) {
    web.text($ctx, 200, "hello, " + web.query($ctx, "name") + "\n");
}
def app as web.App init web.new();
$app = web.get($app, "/hello", hello);
web.run($app, "127.0.0.1:8080");
```

```text
$ jennifer serve hello.j        # --watch: restart on every save
GET /hello?name=Ada -> 200 hello, Ada     HEAD /hello -> 200
GET /nope           -> 404                POST /hello -> 404
```

<!-- notes:
A handler is an ordinary top-level function that takes a web.Context. The
route table stores it as a function value: you pass the bare name, and a typo
fails when the program loads, not on the first request. Registrars return a
new App, so you thread it through with assignments. A HEAD request is served
by the GET route automatically. Note that a POST to a GET-only route is a
404, not a 405. jennifer serve runs the app; with --watch it restarts on
every change to the entry file.
-->

---

## Shelf's route table

```jennifer excerpt
def app as web.App init web.new();
$app = web.before($app, guardCsrf);        # middleware, in this order
$app = web.before($app, requireLogin);
$app = web.get($app, "/", listBooks);
$app = web.get($app, "/login", showLogin);
$app = web.post($app, "/login", doLogin);
$app = web.post($app, "/logout", doLogout);
$app = web.post($app, "/books", addBook);
$app = web.post($app, "/books/:id/done", markDone);
$app = web.get($app, "/healthz", health);
$app = web.get($app, "/static/*path", staticFile);
```

Handlers run **concurrently**: never write a top-level `def` from one.

<!-- notes:
A colon segment captures one parameter, read with web.param; a trailing star
segment captures the rest of the path. The first matching route wins, so a
catch-all goes last. The most important rule is the bold one: web.run hands
every request to its own spawned worker, and those workers share the entry
program's globals. Reading them is safe; writing one from two handlers at
once is a race. So the connection and the session store are set once at
startup and only read afterwards.
-->

---

## Configuration from the environment

```jennifer excerpt
# NAME, or the contents of the file NAME_FILE names
func setting(name as string, fallback as string) {
    def path as string init os.getEnv($name + "_FILE");
    if ($path != "") { return strings.trim(fs.readString($path)); }
    if (os.hasEnv($name)) { return os.getEnv($name); }
    return $fallback;
}
def dsn as string init setting("SHELF_DB_DSN", "");
def csrfSecret as string init setting("SHELF_CSRF_SECRET", "");
if ($dsn == "" or len($csrfSecret) < 32) {
    io.eprintf("shelf: set SHELF_DB_DSN, SHELF_CSRF_SECRET\n");
    exit 2;
}
```

<!-- notes:
No configuration file: everything comes from the environment, which is what
a container, a systemd unit and a test all provide easily. The _FILE variant
reads a secret from a mounted file instead, so it never shows up in the
process environment. A missing setting stops the program before it listens,
with exit code 2, so a service manager can tell a configuration error from a
crash. For local development the dotenv module can load a .env file.
-->

---

## The database: MariaDB through `sql`

```jennifer excerpt
def conn as sql.Connection init sql.open("mariadb", $dsn);
# "shelf:PASSWORD@tcp(127.0.0.1:3306)/shelf"
```

- Drivers: `mysql` / `mariadb` and `postgres`; **no SQLite**
- `open` pings, so a wrong DSN fails at startup; the password is redacted
  from the error
- The connection is a **pool**: one per program, shared by all handlers
- Values go in only through placeholders: `?` here, `$1` on PostgreSQL

<!-- notes:
The sql library is part of the default jennifer binary; jennifer-tiny does
not have it. There is no embedded database, so even a small app needs a
server; a container makes that painless, as the test slides show. The
connection handle is a pool and is safe to use from concurrent handlers, so
we open it once, at the top level. Every query and exec runs under a 30
second client deadline by default, adjustable with sql.setQueryTimeout.
-->

---

## Migrations with `sqlmigrate`

```jennifer excerpt
def const MIGRATIONS as list of mig.Migration init [
    mig.Migration{version: "001", description: "members",
        up: ["CREATE TABLE members (id INT AUTO_INCREMENT PRIMARY KEY," +
            " name VARCHAR(64) NOT NULL UNIQUE," +
            " pwhash VARCHAR(255) NOT NULL)"],
        down: ["DROP TABLE members"]},
    # 002 "books": id, title, author, added_by -> members(id), done
];
```

`store.open($dsn)`: `sql.open`, then `mig.migrate($conn, MIGRATIONS)`, at
every start, with `errdefer sql.close($conn)`.

<!-- notes:
store.open connects and brings the schema up to date, every time the app
starts. sqlmigrate keeps a schema_migrations table, runs only the versions not
in it, in lexical order, so zero-pad them. Each migration runs in a
transaction, but MariaDB commits every CREATE TABLE on its own, so one table
per migration keeps a failed step easy to repeat. errdefer closes the
connection only if the migration throws; on success the caller gets it open.
-->

---

## Reading and writing rows

```jennifer excerpt
# books(conn): every book, unread first
def rows as sql.Rows init sql.query($conn,
    "SELECT b.id, title, author, name, done FROM books b" +
    " JOIN members m ON m.id = added_by ORDER BY done, b.id");
while (sql.next($rows)) {
    $out[] = Book{id: sql.asInt($rows, 0),
        title: sql.asString($rows, 1),
        author: sql.asString($rows, 2),
        addedBy: sql.asString($rows, 3),
        done: sql.asBool($rows, 4)};
}
```

<!-- notes:
The cursor is pull-based: next advances, the typed accessors read a column by
index or by name. A NULL column is an error, so check sql.isNull first where
one can occur. Running the loop to its end closes the cursor; when you leave
early, defer sql.closeRows. Writes use sql.exec, which returns affected and
lastId. markDone runs UPDATE books SET done = TRUE WHERE id = ? AND NOT done
and reports affected == 1: MariaDB counts only rows it actually changed, so
"already read" and "no such book" both give false, and the handler says 404.
-->

---

## Passwords: argon2id

```jennifer excerpt
def h as string init crypto.hashPassword("argon2id", $password);  # add
# login(): the member's id, or 0
def rows as sql.Rows init sql.query($conn,
    "SELECT id, pwhash FROM members WHERE name = ?", $name);
defer sql.closeRows($rows);
if (not sql.next($rows)) { return 0; }
def hash as string init sql.asString($rows, "pwhash");
if (not crypto.verifyPassword($password, $hash)) { return 0; }
return sql.asInt($rows, "id");
```

```text
$ echo 'correct horse battery' | jennifer run addmember.j ada
member 1: ada
```

<!-- notes:
hashPassword picks a fresh random salt and the parameters, 64 MiB and three
passes for argon2id, and writes all of it into one self-describing string, so
the column is all you store. verifyPassword reads the parameters back and
compares in constant time. There is no sign-up page: addmember.j reads the
password from standard input, so it never appears in the shell history or the
process list. One refinement for later: an unknown name returns faster than a
wrong password, which tells an attacker which names exist.
-->

---

## Sessions: a fresh id at every login

```jennifer excerpt
# doLogin, once store.login returned an id:
def sid as string init session.create($sessions, SESSION_TTL);
def data as json.Value init json.map({"member": $id, "name": $name});
session.save($sessions, $sid, $data, SESSION_TTL);
web.setCookie($ctx, "sid", $sid, cookieOptions(SESSION_TTL));
web.redirect($ctx, 303, "/");
# doLogout:
session.destroy($sessions, web.cookie($ctx, "sid"));
web.setCookie($ctx, "sid", "", cookieOptions(-1));   # expire it now
```

`$sessions` is `kvstore.inProcessStore()`; the cookie is `HttpOnly`,
`SameSite=Lax`, `Path=/`, and `Secure`.

<!-- notes:
The session module keeps a JSON value per id in a kvstore with a sliding
expiry. The id is a random UUID, created only after the password checked out,
so an id an attacker planted before the login is worthless after it: that is
the fixation defence. HttpOnly keeps it from scripts, SameSite=Lax from most
cross-site requests. The in-process store forgets every session on a
restart and is not shared between two processes; kvstore.redisStore over a
redis connection fixes both, and only the line that makes the store changes.
-->

---

## Middleware: who may see what

```jennifer excerpt
func requireLogin(ctx as web.Context) {
    def p as string init web.path($ctx);
    if ($p == "/login" or $p == "/healthz" or
        strings.startsWith($p, "/static/")) {
        return true;
    }
    if (json.has(current($ctx), "/member")) { return true; }
    web.redirect($ctx, 303, "/login");
    return false;
}
```

`current($ctx)`: the `sid` cookie; if `session.exists`, `touch` and `load`
it, else an empty object.

<!-- notes:
A middleware is a handler that returns a bool: true lets the request through,
false means it has already answered. Putting the login check in one
middleware, instead of in each handler, means a new route is protected by
default and has to be let out on purpose, like the login page, the health
check and the static files here. Checking exists before reading also refuses
an id the client made up. touch slides the expiry, so an active member stays
signed in.
-->

---

## Forms: validate, write, redirect

```jennifer excerpt
# addBook(ctx), for POST /books
def title as string init strings.trim(web.formValue($ctx, "title"));
def author as string init strings.trim(web.formValue($ctx, "author"));
if ($title == "" or $author == "" or len($title) > 200 or
    len($author) > 200) {
    web.text($ctx, 422, "title and author: 1 to 200 characters\n");
    return;
}
def me as int init json.asInt(current($ctx), "/member");
store.addBook($db, $me, $title, $author);
web.redirect($ctx, 303, "/");     # post, redirect, get
```

<!-- notes:
formValue reads one field of a urlencoded body, and returns an empty string
when it is missing. The checks mirror the columns: VARCHAR(200) counts
characters, and so does len on a string. The required attribute in the HTML
form is a convenience for the user, not a check: anyone can send a POST
without the form. After a successful write the answer is 303 See Other, so
the browser loads the list with a GET and a reload does not add the book
again. For many rules there is the validate module.
-->

---

## Templates: `tengine`, escaped by hand

```jennifer excerpt
def const LIST as string init '{{ define "main" }}
<ul>
{{- range .books }}
  <li>{{ .title | html }} by {{ .author | html }}
  {{- if .done }} - read{{ else }}
    <form method="post" action="/books/{{ .id }}/done">
      <input type="hidden" name="csrf" value="{{ $.csrf }}">
      <button>Mark as read</button></form>{{ end }}</li>
{{- end }}
</ul>{{ end }}';
```

```text
<li>&lt;script&gt;alert(1)&lt;/script&gt; by Mallory (added by ada) - read</li>
```

<!-- notes:
tengine is a subset of Go's text/template over a json.Value. Like text/template,
and unlike html/template, it escapes nothing on its own, so every value a
user controls goes through the html pipe. The line underneath is real output
after a member added a book titled with a script tag. A layout template with
template "main" wraps each page. The alternative is the html module, which
builds a node tree and escapes every text node and attribute by construction.
-->

---

## CSRF: a token in every form

```jennifer excerpt
func showLogin(ctx as web.Context) {
    def token as string init web.csrfToken($ctx, $csrfSecret);
    web.html($ctx, 200, views.login("", "", $token));
}
func guardCsrf(ctx as web.Context) {
    if (web.method($ctx) != "POST" or web.csrfCheck($ctx, $csrfSecret)) {
        return true;
    }
    web.text($ctx, 403, "CSRF check failed\n");
    return false;
}
```

Plain-HTTP development: `JENNIFER_WEB_INSECURE_COOKIES=1`.

<!-- notes:
Another site can make a member's browser post to Shelf, with the member's
cookies. It cannot read the token, so the forged post fails. The token is a
random value plus its HMAC under the secret; it goes out in the csrf cookie
and comes back in the hidden csrf field or an X-CSRF-Token header. Both
cookies are Secure, so plain HTTP needs the variable shown. csrfToken mints
a token per request and returns the same one on every later call in that
request, so a page with many forms carries one token. guardCsrf runs before
requireLogin, so the login form is protected too. The secret must stay the
same across restarts, or every open form breaks; that is why it is a setting.
-->

---

## What the server answered

```text
POST /login  without a token                  -> 403 Forbidden
POST /login  token, wrong password            -> 401 "Wrong name or password."
POST /login  token, right password            -> 303 Location: /
             Set-Cookie: sid=...; Path=/; Max-Age=28800; HttpOnly; SameSite=Lax
POST /books  title "<script>alert(1)</script>"  -> 303, stored, shown escaped
POST /books/1/done                            -> 303
POST /books/1/done  (again)                   -> 404
GET  /       without a session                -> 303 Location: /login
```

<!-- notes:
This is a session with curl against the running app, the sid value shortened.
It was run on plain HTTP with JENNIFER_WEB_INSECURE_COOKIES=1, which is why
the sid cookie lacks Secure; behind HTTPS it carries it. Every unsafe request
needed the token, and the failed login gave nothing away beyond "wrong name
or password". The second "mark as read" for the same book is a 404, because
the UPDATE changed no row.
-->

---

## Tests against a throwaway database

```jennifer excerpt
func fresh() {
    def server as string init os.getEnv("SHELF_TEST_DSN");
    def name as string init "shelftest_" + uuid.v4()[..8];
    def admin as sql.Connection init sql.open("mariadb", $server);
    sql.exec($admin, "CREATE DATABASE " + $name);
    def conn as sql.Connection init open($server + $name); # migrated
    return Fixture{admin: $admin, conn: $conn, name: $name};
}
func dispose(f as Fixture) {
    sql.close($f.conn);
    sql.exec($f.admin, "DROP DATABASE " + $f.name);
    sql.close($f.admin);
}
```

<!-- notes:
src/store_test.j is an overlay: jennifer test splices store.j in front of it,
so it calls open, addBook and the rest by their bare names. SHELF_TEST_DSN
names the server without a database, and Fixture holds both connections and
the name. Each test gets a database of its own, with a random name, migrated
by the real open function, and dropped again by a defer, even when an
assertion fails. So tests cannot see each other's rows, never touch development data,
and exercise the same schema, constraints and SQL dialect as production. A
stub would not have caught the affected-rows rule from the earlier slide. The
name is ours, not user input, which is why it may be concatenated into SQL.
-->

---

## A test

```jennifer excerpt
func testBooksListUnreadFirst() {
    if (os.getEnv("SHELF_TEST_DSN") == "") { return; }   # skip
    def f as Fixture init fresh();
    defer dispose($f);
    def ada as int init addMember($f.conn, "ada", "correct horse battery");
    def first as int init addBook($f.conn, $ada, "Kindred", "O. E. Butler");
    addBook($f.conn, $ada, "Solaris", "Stanislaw Lem");
    testing.assertTrue(markDone($f.conn, $first));
    testing.assertFalse(markDone($f.conn, $first));     # already read
    testing.assertEqual(books($f.conn)[0].title, "Solaris");
}
```

<!-- notes:
A test is a function whose name starts with test; jennifer test finds them
and runs them one after another. The fixture comes first and its disposal is
deferred right after, so the database goes away whatever the assertions do.
The test reads like the feature: two books, one marked as read, the unread
one listed first, and marking the same book twice is refused the second time.
-->

---

## Running the tests

```text
$ docker run -d --rm --name shelf-testdb -e MARIADB_ROOT_PASSWORD=test \
    -p 127.0.0.1:3399:3306 --tmpfs /var/lib/mysql mariadb:11.4
$ SHELF_TEST_DSN='root:test@tcp(127.0.0.1:3399)/' \
    jennifer test src/store_test.j
PASS testBooksListUnreadFirst (67 ms)
PASS testLoginChecksThePassword (353 ms)
PASS testNamesAreUnique (121 ms)
```

- The server is throwaway too: `--rm`, data on a `tmpfs`
- No `SHELF_TEST_DSN`: the tests skip; CI sets it

<!-- notes:
The server itself is throwaway too: a container with its data directory on a
tmpfs, gone when it stops, so nothing is written to disk and nothing has to
be cleaned up. Without SHELF_TEST_DSN the tests return at once and pass, so a
laptop without Docker still runs the rest of the suite; CI sets the variable.
The login test is the slow one because argon2id is slow on purpose, which is
the point of a password hash.
-->

---

## A clean stop

```jennifer excerpt
os.catchSignal("term"); os.catchSignal("int");
def watcher as task of null init spawn {
    while (not os.gotSignal("term") and not os.gotSignal("int")) {
        time.sleep(time.fromMilliseconds(200));
    }
    httpd.shutdown($srv);     # from httpd.listen($addr)
    return null;
};
web.serveOn($app, $srv);      # returns after the shutdown
sql.close($db);
```

```text
shelf: shutting down
shelf: stopped
```

<!-- notes:
web.run is fine for a demo. Here we listen ourselves and serve with
web.serveOn, so we hold the server handle. A small task polls for SIGTERM or
Ctrl-C and calls httpd.shutdown, which stops accepting and gives requests
already accepted five seconds to finish. Then serveOn returns and the program
closes the pool. Without this, SIGTERM ends the process at once, in the
middle of whatever it was doing. systemctl stop and docker stop both send
SIGTERM.
-->

---

## Where to go from here

- **Rate-limit** the login: `ratelimit.fixedWindow` over the same `kvstore`
- **Several processes:** `kvstore.redisStore` for the sessions
- **JSON APIs:** `webapi` adds auth, scopes, validation and 429s on top of `web`
- **Ship it:** the companion talk puts Shelf into a container
- Docs: [web](https://docs.jennifer-lang.dev/modules/web.html),
  [sql](https://docs.jennifer-lang.dev/libraries/sql.html), and the
  [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
Shelf is deliberately small, but it is not a toy: placeholders everywhere,
argon2id, fresh session ids, escaped output, CSRF tokens and real tests. The
next things a public deployment needs are a rate limit on the login form and
TLS in front, usually from a reverse proxy. The packaging talk takes the same
three files, builds an image on the official interpreter image, adds a
health check and runs it next to MariaDB with compose.
-->

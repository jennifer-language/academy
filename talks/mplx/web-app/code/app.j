# Shelf: a reading list for a book club.
# Run: SHELF_DB_DSN='shelf:PASSWORD@tcp(127.0.0.1:3306)/shelf' \
#      SHELF_CSRF_SECRET=$(openssl rand -hex 32) jennifer run app.j
# Settings come from the environment; see setting() below.
use convert;
use fs;
use httpd;
use io;
use json;
use os;
use regex;
use sql;
use strings;
use task;
use time;
import "web.j" as web;
import "session.j" as session;
import "kvstore.j" as kvstore;
import "./src/store.j" as store;
import "./src/views.j" as views;

def const SESSION_TTL as int init 8 * 3600;

# --- configuration ---------------------------------------------------

# NAME, or the contents of the file NAME_FILE names
func setting(name as string, fallback as string) {
    def path as string init os.getEnv($name + "_FILE");
    if ($path != "") {
        return strings.trim(fs.readString($path));
    }
    if (os.hasEnv($name)) {
        return os.getEnv($name);
    }
    return $fallback;
}

def dsn as string init setting("SHELF_DB_DSN", "");
def csrfSecret as string init setting("SHELF_CSRF_SECRET", "");
def addr as string init setting("SHELF_ADDR", ":8080");
if ($dsn == "" or len($csrfSecret) < 32) {
    io.eprintf("shelf: set SHELF_DB_DSN, SHELF_CSRF_SECRET\n");
    exit 2;
}

# set once here, only read by the handlers
def db as sql.Connection init store.open($dsn);
def sessions as kvstore.Store init kvstore.inProcessStore();

# --- sessions ----------------------------------------------------------

func cookieOptions(maxAge as int) {
    return web.CookieOptions{path: "/", domain: "", maxAge: $maxAge,
        httpOnly: true, sameSite: "Lax",
        secure: os.getEnv("JENNIFER_WEB_INSECURE_COOKIES") == ""};
}

# the signed-in member's session data, or an empty object
func current(ctx as web.Context) {
    def sid as string init web.cookie($ctx, "sid");
    if (not regex.matches('^[0-9a-f-]{36}$', $sid) or
        not session.exists($sessions, $sid)) {
        return json.map();
    }
    session.touch($sessions, $sid, SESSION_TTL);
    return session.load($sessions, $sid);
}

# --- middleware --------------------------------------------------------

func guardCsrf(ctx as web.Context) {
    if (web.method($ctx) != "POST" or web.csrfCheck($ctx, $csrfSecret)) {
        return true;
    }
    web.text($ctx, 403, "CSRF check failed\n");
    return false;
}

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

# --- handlers ----------------------------------------------------------

func showLogin(ctx as web.Context) {
    def token as string init web.csrfToken($ctx, $csrfSecret);
    web.html($ctx, 200, views.login("", "", $token));
}

func doLogin(ctx as web.Context) {
    def name as string init strings.trim(web.formValue($ctx, "name"));
    def id as int init store.login($db, $name, web.formValue($ctx, "password"));
    if ($id == 0) {
        def token as string init web.csrfToken($ctx, $csrfSecret);
        web.html($ctx, 401, views.login($name, "Wrong name or password.", $token));
        return;
    }
    # a fresh id at every login: a planted one is worthless
    def sid as string init session.create($sessions, SESSION_TTL);
    def data as json.Value init json.map({"member": $id, "name": $name});
    session.save($sessions, $sid, $data, SESSION_TTL);
    web.setCookie($ctx, "sid", $sid, cookieOptions(SESSION_TTL));
    web.redirect($ctx, 303, "/");
}

func doLogout(ctx as web.Context) {
    session.destroy($sessions, web.cookie($ctx, "sid"));
    web.setCookie($ctx, "sid", "", cookieOptions(-1));   # expire it now
    web.redirect($ctx, 303, "/login");
}

func listBooks(ctx as web.Context) {
    def name as string init json.asString(current($ctx), "/name");
    def token as string init web.csrfToken($ctx, $csrfSecret);
    web.html($ctx, 200, views.shelf(store.books($db), $name, $token));
}

# addBook(ctx), for POST /books
func addBook(ctx as web.Context) {
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
}

func markDone(ctx as web.Context) {
    def id as string init web.param($ctx, "id");
    if (regex.matches('^[0-9]{1,9}$', $id) and
        store.markDone($db, convert.toInt($id))) {
        web.redirect($ctx, 303, "/");
        return;
    }
    web.text($ctx, 404, "no such unread book\n");
}

# no database query: a slow database must not fail every health check
func health(ctx as web.Context) {
    web.text($ctx, 200, "ok\n");
}

func staticFile(ctx as web.Context) {
    web.serveDir($ctx, "public");
}

# --- routes and serving ------------------------------------------------

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

def srv as httpd.Server init httpd.listen($addr);
io.printf("shelf: listening on %s\n", httpd.address($srv));
os.catchSignal("term"); os.catchSignal("int");
def watcher as task of null init spawn {
    while (not os.gotSignal("term") and not os.gotSignal("int")) {
        time.sleep(time.fromMilliseconds(200));
    }
    io.printf("shelf: shutting down\n");
    httpd.shutdown($srv);     # from httpd.listen($addr)
    return null;
};
web.serveOn($app, $srv);      # returns after the shutdown
task.wait($watcher);
sql.close($db);
io.printf("shelf: stopped\n");

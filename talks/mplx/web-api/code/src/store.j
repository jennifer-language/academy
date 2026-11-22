# store.j - the schema, its migrations, and every query of the shop API
# pragma-jennifer-capability: sql

use sql;
use strings;
use hash;
use encoding;
use crypto;
use convert;
import "orm.j" as orm;
import "sqlmigrate.j" as mig;

# Migrations are frozen text: never build an old one from a schema that
# keeps changing.
export def const MIGRATIONS as list of mig.Migration init [
    mig.Migration{version: "001", description: "api users and tokens",
        up: ["CREATE TABLE api_users (id SERIAL PRIMARY KEY," +
            " name TEXT NOT NULL UNIQUE, pwhash TEXT NOT NULL," +
            " scopes TEXT NOT NULL)",
            "CREATE TABLE api_tokens (hash TEXT PRIMARY KEY," +
            " user_id INT NOT NULL REFERENCES api_users(id)," +
            " created_at TIMESTAMPTZ NOT NULL DEFAULT now())"],
        down: ["DROP TABLE api_tokens", "DROP TABLE api_users"]},
    mig.Migration{version: "002", description: "orders",
        up: ["CREATE TABLE orders (id SERIAL PRIMARY KEY," +
            " customer TEXT NOT NULL, lines TEXT NOT NULL," +
            " total_cents INT NOT NULL, state TEXT NOT NULL," +
            " created_by INT NOT NULL REFERENCES api_users(id))",
            orm.createIndex("orders_state", "orders", ["state"], false)],
        down: ["DROP TABLE orders"]},
    mig.Migration{version: "003", description: "idempotency keys",
        up: ["CREATE TABLE idempotency_keys (user_id INT NOT NULL," +
            " key TEXT NOT NULL, request_hash TEXT NOT NULL," +
            " status INT NOT NULL, body TEXT NOT NULL," +
            " created_at TIMESTAMPTZ NOT NULL DEFAULT now()," +
            " PRIMARY KEY (user_id, key))"],
        down: ["DROP TABLE idempotency_keys"]}
];

# The orders table as orm sees it: queries and CRUD, not DDL.
export func orders() {
    def s as orm.Schema init orm.schema("orders", "id", orm.Dialect.Postgres);
    $s = orm.column($s, "id", orm.ColumnKind.Int);
    $s = orm.column($s, "customer", orm.ColumnKind.String);
    $s = orm.column($s, "lines", orm.ColumnKind.String);
    $s = orm.column($s, "total_cents", orm.ColumnKind.Int);
    $s = orm.column($s, "state", orm.ColumnKind.String);
    return orm.column($s, "created_by", orm.ColumnKind.Int);
}

export def struct Filter {
    state as string,
    customer as string,
    offset as int,
    limit as int
};

# The query behind GET /v1/orders, without paging (for the count).
export func filtered(f as Filter) {
    def q as orm.Query init orm.from(orders());
    if ($f.state != "") { $q = orm.where($q, "state", "=", $f.state); }
    if ($f.customer != "") {
        $q = orm.where($q, "customer", "=", $f.customer);
    }
    return $q;
}

export func listQuery(f as Filter) {
    def q as orm.Query init orm.orderBy(filtered($f), "id", "desc");
    return orm.offset(orm.limit($q, $f.limit), $f.offset);
}

export func countQuery(f as Filter) {
    return orm.count(orm.select(filtered($f), []), "n");
}

export func listOrders(conn as sql.Connection, f as Filter) {
    return orm.all(orm.session($conn), listQuery($f));
}

export func countOrders(conn as sql.Connection, f as Filter) {
    def row as map of string to string init
        orm.first(orm.session($conn), countQuery($f));
    return convert.toInt($row["n"]);
}

export func findOrder(conn as sql.Connection, id as string) {
    return orm.findBy(orm.session($conn), orders(), "id", $id);
}

# --- API users and tokens ---------------------------------------------------

export def struct Caller {
    found as bool,
    id as int,
    name as string,
    scopes as list of string
};

# A hash of a password nobody has, so an unknown name costs one argon2id
# check, like a known one.
export def const DUMMY_HASH as string init
    '$argon2id$v=19$m=65536,t=3,p=4$6vCTKdAFRZuXR0SeIrjtZQ$' +
    'IKFRWzomJT7xNYPmC7QATHJ/Ko+eu6f549Y0QyH6tWU';

export func addUser(conn as sql.Connection, name as string, pw as string,
    scopes as string) {
    def h as string init crypto.hashPassword("argon2id", $pw);
    def rows as sql.Rows init sql.query($conn,
        "INSERT INTO api_users (name, pwhash, scopes) VALUES ($1, $2, $3)" +
        " RETURNING id", $name, $h, $scopes);
    defer sql.closeRows($rows);
    sql.next($rows);
    return sql.asInt($rows, "id");
}

# The user id for a name and password, or 0.
export func login(conn as sql.Connection, name as string, pw as string) {
    def rows as sql.Rows init sql.query($conn,
        "SELECT id, pwhash FROM api_users WHERE name = $1", $name);
    defer sql.closeRows($rows);
    if (not sql.next($rows)) {
        crypto.verifyPassword($pw, DUMMY_HASH);
        return 0;
    }
    if (not crypto.verifyPassword($pw, sql.asString($rows, "pwhash"))) {
        return 0;
    }
    return sql.asInt($rows, "id");
}

export func tokenHash(token as string) {
    return encoding.toText("hex",
        hash.compute("sha256", encoding.encode("utf-8", $token)));
}

# Mint a token: the caller sees it once, the database keeps its hash.
export func newToken(conn as sql.Connection, userId as int) {
    def token as string init "shp_" +
        encoding.toText("hex", crypto.randBytes(24));
    sql.exec($conn, "INSERT INTO api_tokens (hash, user_id)" +
        " VALUES ($1, $2)", tokenHash($token), $userId);
    return $token;
}

export func caller(conn as sql.Connection, token as string) {
    def rows as sql.Rows init sql.query($conn,
        "SELECT u.id, u.name, u.scopes FROM api_tokens t" +
        " JOIN api_users u ON u.id = t.user_id WHERE t.hash = $1",
        tokenHash($token));
    defer sql.closeRows($rows);
    def none as list of string init [];
    if (not sql.next($rows)) {
        return Caller{found: false, id: 0, name: "", scopes: $none};
    }
    return Caller{found: true, id: sql.asInt($rows, "id"),
        name: sql.asString($rows, "name"),
        scopes: strings.split(sql.asString($rows, "scopes"), " ")};
}

# --- idempotency keys -----------------------------------------------------------

# Claim a key inside the caller's transaction: true when it is new. A second
# request with the same key waits here until the first one commits.
export func claimKey(tx as sql.Tx, uid as int, key as string, reqHash as string) {
    def r as sql.Result init sql.exec($tx,
        "INSERT INTO idempotency_keys (user_id, key, request_hash, status, body)" +
        " VALUES ($1, $2, $3, 0, '') ON CONFLICT DO NOTHING",
        $uid, $key, $reqHash);
    return $r.affected == 1;
}

export func saveResponse(tx as sql.Tx, uid as int, key as string, status as int,
    body as string) {
    sql.exec($tx, "UPDATE idempotency_keys SET status = $3, body = $4" +
        " WHERE user_id = $1 AND key = $2", $uid, $key, $status, $body);
}

export def struct Saved {
    requestHash as string,
    status as int,
    body as string
};

export func savedResponse(conn as sql.Connection, uid as int, key as string) {
    def rows as sql.Rows init sql.query($conn,
        "SELECT request_hash, status, body FROM idempotency_keys" +
        " WHERE user_id = $1 AND key = $2", $uid, $key);
    defer sql.closeRows($rows);
    sql.next($rows);
    return Saved{requestHash: sql.asString($rows, 0),
        status: sql.asInt($rows, 1), body: sql.asString($rows, 2)};
}

# The order row, locked until the transaction ends; {} when there is none.
export func lockOrder(tx as sql.Tx, id as string) {
    def rows as sql.Rows init sql.query($tx,
        "SELECT * FROM orders WHERE id = $1 FOR UPDATE", $id);
    defer sql.closeRows($rows);
    def row as map of string to string init {};
    if (sql.next($rows)) {
        for (def c in sql.columns($rows)) {
            $row[$c] = sql.asString($rows, $c);
        }
    }
    return $row;
}

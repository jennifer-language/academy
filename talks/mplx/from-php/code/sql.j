# "Databases without PDO": the slide's query against a PostgreSQL server.
# Set DSN, e.g. DSN=postgres://academy:academy@127.0.0.1:55432/academy
# (see README.md for the docker line). The program creates a small users
# table with three rows first, so it can run against an empty database.
use io;
use os;
use sql;

def dsn as string init os.getEnv("DSN");
def db as sql.Connection init sql.open("postgres", $dsn);
sql.exec($db, "drop table if exists users");
sql.exec($db, "create table users (id int primary key, name text not null)");
def names as list of string init ["Ada", "Alan", "Grace"];
for (def i in 0..len($names)) {
    sql.exec($db, "insert into users (id, name) values ($1, $2)",
        $i + 1, $names[$i]);
}

def rows as sql.Rows init sql.query(
    $db, "select id, name from users where id > $1", 0);
while (sql.next($rows)) {
    io.printf("%d %s\n", sql.asInt($rows, "id"), sql.asString($rows, "name"));
}

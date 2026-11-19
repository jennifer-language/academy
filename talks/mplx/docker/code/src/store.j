# Shelf's SQL: migrations, members, books. Plain functions over a
# sql.Connection; the module holds no state of its own.
use crypto;
use sql;
import "sqlmigrate.j" as mig;

export def struct Book {
    id as int,
    title as string,
    author as string,
    addedBy as string,
    done as bool
};

def const MIGRATIONS as list of mig.Migration init [
    mig.Migration{version: "001", description: "members",
        up: ["CREATE TABLE members (id INT AUTO_INCREMENT PRIMARY KEY," +
            " name VARCHAR(64) NOT NULL UNIQUE," +
            " pwhash VARCHAR(255) NOT NULL)"],
        down: ["DROP TABLE members"]},
    mig.Migration{version: "002", description: "books",
        up: ["CREATE TABLE books (id INT AUTO_INCREMENT PRIMARY KEY," +
            " title VARCHAR(200) NOT NULL," +
            " author VARCHAR(200) NOT NULL," +
            " added_by INT NOT NULL," +
            " done BOOLEAN NOT NULL DEFAULT FALSE," +
            " FOREIGN KEY (added_by) REFERENCES members(id))"],
        down: ["DROP TABLE books"]}
];

# open connects and brings the schema up to date
export func open(dsn as string) {
    def conn as sql.Connection init sql.open("mariadb", $dsn);
    errdefer sql.close($conn);
    mig.migrate($conn, MIGRATIONS);
    return $conn;
}

# addMember stores a new member with an argon2id hash; returns the id
export func addMember(conn as sql.Connection, name as string, password as string) {
    def h as string init crypto.hashPassword("argon2id", $password);
    def r as sql.Result init sql.exec($conn,
        "INSERT INTO members (name, pwhash) VALUES (?, ?)", $name, $h);
    return $r.lastId;
}

# login(): the member's id, or 0
export func login(conn as sql.Connection, name as string, password as string) {
    def rows as sql.Rows init sql.query($conn,
        "SELECT id, pwhash FROM members WHERE name = ?", $name);
    defer sql.closeRows($rows);
    if (not sql.next($rows)) { return 0; }
    def hash as string init sql.asString($rows, "pwhash");
    if (not crypto.verifyPassword($password, $hash)) { return 0; }
    return sql.asInt($rows, "id");
}

# addBook stores a book; returns its id
export func addBook(conn as sql.Connection, member as int, title as string,
        author as string) {
    def r as sql.Result init sql.exec($conn,
        "INSERT INTO books (title, author, added_by) VALUES (?, ?, ?)",
        $title, $author, $member);
    return $r.lastId;
}

# books(conn): every book, unread first
export func books(conn as sql.Connection) {
    def out as list of Book init [];
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
    return $out;
}

# markDone: true when the book existed and was not read yet
export func markDone(conn as sql.Connection, id as int) {
    def r as sql.Result init sql.exec($conn,
        "UPDATE books SET done = TRUE WHERE id = ? AND NOT done", $id);
    return $r.affected == 1;
}

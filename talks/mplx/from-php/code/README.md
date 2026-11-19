# From PHP to Jennifer: the code

The Jennifer programs behind the slides, plus the PHP side of the comparison
tables. Run everything from this folder with Jennifer 0.26.0; only `web.j`
and `sql.j` need more than that.

- `declare.j`: "Declare before you use". Run: `jennifer run declare.j`
- `juggling.j`: every row of "No type juggling" and "Numbers keep their
  promises", with the errors caught and printed so the program runs to the
  end. Run: `jennifer run juggling.j`
- `strings.j`: "Strings", plus a raw single-quoted string. Run:
  `jennifer run strings.j`
- `arrays.j`: "One array becomes two types", prints the three prices in
  insertion order. Run: `jennifer run arrays.j`
- `objects.j`: "Objects become values", prints `Ada has 150`.
  Run: `jennifer run objects.j`
- `match.j`: "match, as in PHP 8", prints `gone`. Run: `jennifer run match.j`
- `exceptions.j`: "Exceptions, without finally", prints `funds: too little`.
  Run: `jennifer run exceptions.j`
- `imports.j` with `util.j`: "include, Composer and Packagist", an `import`
  of a local module and the built-in `json` library. Run:
  `jennifer run imports.j`
- `web.j`: "The web: a server, not a request". Listens on 127.0.0.1:8080
  until stopped with Ctrl-C. Run: `jennifer run web.j`, then
  `curl http://127.0.0.1:8080/hello/Ada` answers `Hello, Ada!`
- `sql.j`: "Databases without PDO", the slide's query with the setup around
  it (it drops and recreates a `users` table with three rows). Needs a
  PostgreSQL server, for example
  `docker run -d --name academy-pg -e POSTGRES_USER=academy -e POSTGRES_PASSWORD=academy -e POSTGRES_DB=academy -p 127.0.0.1:55432:5432 postgres:16`.
  Run: `DSN=postgres://academy:academy@127.0.0.1:55432/academy jennifer run sql.j`
  (prints `1 Ada`, `2 Alan`, `3 Grace`); remove the server afterwards with
  `docker rm -f academy-pg`.
- `php/juggling.php.txt` and `php/basics.php.txt`: the PHP column of the
  tables and the PHP snippets from "Declare before you use" and "Strings", to
  compare. They are PHP scripts saved as `.txt` (the code folder holds no
  `.php` files) and need PHP 8, for example
  `cd php && docker run --rm -i php:8.3-cli php < juggling.php.txt`
  (prints `bool(true)`, `int(6)`, `truthy`, `int(42)`, `float(3.5)`,
  `int(3)`, `int(-1)` and `float(9.223372036854776E+18)`).

# Running Shelf

Shelf runs from the container image next to MariaDB, started with
`docker compose up -d --build`.

## Settings

| Variable | Meaning |
| --- | --- |
| `SHELF_DB_DSN` | the database, `user:password@tcp(host:3306)/shelf` |
| `SHELF_CSRF_SECRET` | 32 characters or more, the same across restarts |
| `SHELF_ADDR` | the listen address, `:8080` by default |

Each also reads `NAME_FILE`, the path of a file holding the value.

## Members

There is no sign-up page. Create a member with the password on standard
input:

    printf '%s\n' "$PW" | docker compose exec -T app jennifer run addmember.j ada

## Backups

Back up the database volume with `mariadb-dump`, not the container.

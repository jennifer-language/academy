#!/bin/sh
# Drives a running Shelf with curl, as on "What the server answered".
# Needs member ada (password: correct horse battery) and an empty books
# table; BASE defaults to http://127.0.0.1:8080.
set -eu
BASE=${BASE:-http://127.0.0.1:8080}
J=$(mktemp)
trap 'rm -f "$J"' EXIT
code() { curl -s -o /dev/null -w '%{http_code} %{redirect_url}' "$@"; echo; }
token() { curl -s -c "$J" -b "$J" "$BASE/login" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1; }
T=$(token)
printf 'POST /login  without a token            -> '; code -b "$J" -d name=ada -d 'password=x' "$BASE/login"
printf 'POST /login  token, wrong password      -> '; curl -s -w ' %{http_code}\n' -b "$J" -d csrf="$T" -d name=ada -d 'password=wrong' "$BASE/login" | grep -o 'Wrong name or password\.\|[0-9][0-9][0-9]$' | tr '\n' ' '; echo
printf 'POST /login  token, right password      -> '; curl -s -D - -o /dev/null -b "$J" -c "$J" -d csrf="$T" -d name=ada --data-urlencode 'password=correct horse battery' "$BASE/login" | grep -i '^HTTP\|^location\|^set-cookie' | tr -d '\r' | tr '\n' ' '; echo
T=$(curl -s -b "$J" -c "$J" "$BASE/" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1)
printf 'POST /books  script title               -> '; code -b "$J" -d csrf="$T" --data-urlencode 'title=<script>alert(1)</script>' -d author=Mallory "$BASE/books"
printf 'POST /books/1/done                      -> '; code -b "$J" -d csrf="$T" "$BASE/books/1/done"
printf 'POST /books/1/done  (again)             -> '; code -b "$J" -d csrf="$T" "$BASE/books/1/done"
printf 'GET  /       without a session          -> '; code "$BASE/"
echo '--- the list:'; curl -s -b "$J" "$BASE/" | grep '<li>'

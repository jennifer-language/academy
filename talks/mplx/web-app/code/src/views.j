# Shelf's HTML. tengine escapes nothing on its own: every value a user
# controls goes through the html pipe.
use json;
import "tengine.j" as tengine;
import "./store.j" as store;

def const LAYOUT as string init '<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Shelf</title>
<link rel="stylesheet" href="/static/shelf.css">
</head>
<body>
<header><h1>Shelf</h1>
{{- if .name }}
<form method="post" action="/logout">
  <input type="hidden" name="csrf" value="{{ .csrf }}">
  {{ .name | html }} <button>Sign out</button></form>
{{- end }}
</header>
<main>
{{ template "main" . }}
{{- if .name }}{{ template "add" . }}{{ end }}
</main>
</body>
</html>
';

def const LOGIN as string init '{{ define "main" }}
{{- if .error }}<p class="error">{{ .error | html }}</p>{{ end }}
<form method="post" action="/login">
  <input type="hidden" name="csrf" value="{{ .csrf }}">
  <label>Name <input name="name" value="{{ .user | html }}" required></label>
  <label>Password <input name="password" type="password" required></label>
  <button>Sign in</button>
</form>{{ end }}';

def const ADD as string init '{{ define "add" }}
<form method="post" action="/books">
  <input type="hidden" name="csrf" value="{{ .csrf }}">
  <input name="title" placeholder="Title" maxlength="200" required>
  <input name="author" placeholder="Author" maxlength="200" required>
  <button>Add</button>
</form>{{ end }}';

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

func page(main as string, data as json.Value) {
    def set as tengine.Set init tengine.newSet();
    $set = tengine.add($set, "layout", LAYOUT);
    $set = tengine.add($set, "add", ADD);
    $set = tengine.add($set, "main", $main);
    return tengine.render($set, "layout", $data);
}

# the login page; user is the name typed so far, error a message or ""
export func login(user as string, error as string, csrf as string) {
    return page(LOGIN, json.map({"user": $user, "error": $error, "csrf": $csrf}));
}

# the reading list for the member called name
export func shelf(books as list of store.Book, name as string, csrf as string) {
    def rows as list of json.Value init [];
    for (def b in $books) {
        $rows[] = json.map({"id": $b.id, "title": $b.title, "author": $b.author,
            "addedBy": $b.addedBy, "done": $b.done});
    }
    def data as json.Value init json.map({"name": $name, "csrf": $csrf});
    return page(LIST, json.set($data, "/books", json.list($rows)));
}

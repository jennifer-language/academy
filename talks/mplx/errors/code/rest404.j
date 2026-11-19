# "The trap: a helper typed Error": the catch binding holds a
# rest.HttpError, and a parameter typed Error refuses it. This program ends
# with that runtime error on purpose; the error also ends the stand-in
# server, so it needs no shutdown here.
use io;
use httpd;
import "rest.j" as rest;
import "./fakeapi.j" as fake;

def srv as httpd.Server init fake.start();
def api as rest.Client init rest.client(fake.URL);

io.printf("asking %s for user 7\n", fake.URL);

# report is the helper from the slide. A catch binding holds whatever was
# thrown, here a rest.HttpError, so the fix is to type the parameter as
# rest.HttpError (typed.j shows that with the stock module).

func report(e as Error) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
try {
    rest.getJson($api, "/users/7", {});
} catch (e) {
    report($e);
}

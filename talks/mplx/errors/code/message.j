# "Match the kind, never the message": the message rest puts in an error
# for a 404, and the check that reads kind and status instead.
use io;
use httpd;
import "rest.j" as rest;
import "./fakeapi.j" as fake;

def srv as httpd.Server init fake.start();
def api as rest.Client init rest.client(fake.URL);
try {
    rest.getJson($api, "/users/7", {});
} catch (e) {
    io.printf("%s\n", $e.message);
    # right: the kind is the contract, the status is a field
    if ($e.kind == "rest" and $e.status == 404) {
        io.printf("not found\n");
    }
}
httpd.shutdown($srv);

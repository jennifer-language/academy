# A stand-in API on a loopback port for message.j and rest404.j: every
# GET /users/:id answers 404 with the body "no such user".
use httpd;
use task;
import "web.j" as web;

def const ADDR as string init "127.0.0.1:18404";
export def const URL as string init "http://" + ADDR;

func noUser(ctx as web.Context) {
    web.text($ctx, 404, "no such user");
}

# start listens, serves from a task and returns the server handle; stop it
# with httpd.shutdown when done.
export func start() {
    def app as web.App init web.new();
    $app = web.get($app, "/users/:id", noUser);
    def srv as httpd.Server init httpd.listen(ADDR);
    def t as task of null init spawn {
        web.serveOn($app, $srv);
        return null;
    };
    task.discard($t);
    return $srv;
}

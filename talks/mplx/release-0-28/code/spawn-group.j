# 0.28.0: a bounded child process. The shell starts a background job, so
# stopping the shell alone would leave the job running: signal the group.
use io;
use os;

def p as os.Process init os.spawnWith(
    ["sh", "-c", "sleep 30 & sleep 30; wait"],
    os.SpawnOptions{
        cleanEnv: true,
        env: {"PATH": "/usr/bin:/bin"},
        group: true
    });

try {
    os.waitTimeout($p, 500);
} catch (e) {
    if ($e.kind != "timeout") {
        throw $e;
    }
    io.printf("still running after 500 ms: %s\n", $e.kind);
    os.signal($p, "term"); # the shell and its background sleep
}
def r as os.Result init os.wait($p);
io.printf("exit code %d\n", $r.exitCode);

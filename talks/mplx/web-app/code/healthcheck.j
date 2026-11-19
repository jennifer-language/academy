# Probe /healthz, for a container HEALTHCHECK: exit 0 when healthy, else 1.
# Run: jennifer run healthcheck.j
use io;
import "http.j" as http;

try {
    def res as http.Response init http.requestWith("GET",
        "http://127.0.0.1:8080/healthz", {}, "", 2000, 4096);
    if ($res.status != 200) {
        io.printf("unhealthy: status %d\n", $res.status);
        exit 1;
    }
} catch (e) {
    io.printf("unhealthy: %s\n", $e.kind);
    exit 1;
}

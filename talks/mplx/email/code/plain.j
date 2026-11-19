use io;
import "imap.j" as imap;
import "transport.j" as transport;
for (def port in [3143, 4143]) {
    try {
        def s as imap.Session init imap.connect(imap.Options{host: "localhost",
            port: $port, security: transport.Security.None,
            user: "ada@example.org", pass: "changeme", auth: ""});
        io.printf("%d: logged in over plaintext\n", $port);
        imap.logout($s);
    } catch (e) {
        io.printf("%d: %s | %s\n", $port, $e.kind, $e.message);
    }
}

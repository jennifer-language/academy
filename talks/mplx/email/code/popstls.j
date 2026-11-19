use io;
import "pop.j" as pop;
import "transport.j" as transport;
def s as pop.Session init pop.connect(pop.Options{host: "localhost", port: 4110,
    security: transport.Security.Starttls, user: "ada@example.org",
    pass: "changeme", auth: "auto"});
io.printf("STLS ok, %d messages\n", pop.count($s));
pop.quit($s);

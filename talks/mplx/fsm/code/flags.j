use io;

# A connection kept in three flags: eight combinations, four of them nonsense.
def struct Conn { connected as bool, loggedIn as bool, closing as bool };

func send(c as Conn, line as string) {
    if (not $c.connected) { return "error: not connected"; }
    if ($c.closing) { return "error: closing"; }
    if (not $c.loggedIn and $line != "LOGIN") { return "error: log in first"; }
    return "sent " + $line;
}

# Logged in and closing, but not connected: the type allows it.
def c as Conn init Conn{connected: false, loggedIn: true, closing: true};
io.printf("%s\n", send($c, "LIST"));

use io;
use toml;
io.printf("%s", toml.encode(toml.decode("# the port\nport = 8080 # http\nhex = 0xff\n")));

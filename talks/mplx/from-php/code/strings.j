use io;

def name as string init "Ada";
def greeting as string init "Hello, " + $name + "!";
io.printf("Hello, {$name}!\n");
# The concatenated string is the same text, and single quotes are raw.
io.printf("%s\n", $greeting);
io.printf('%s' + "\n", 'no {$name}, no \n escapes');

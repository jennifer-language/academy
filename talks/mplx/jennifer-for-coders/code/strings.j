use io;

def word as string init "Jennifer";
io.printf("%s\n", $word[0..3]);
def pattern as string init '\d+\.\d+';
io.printf("%d chars, {$word}\n", len($pattern));

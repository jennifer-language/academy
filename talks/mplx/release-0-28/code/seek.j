# 0.28.0: fs.seek / fs.tell resume a read at a byte offset, and fs.syncDir
# makes a rename survive a crash. It writes and removes demo-seek/ here.
use fs;
use io;

fs.mkdir("demo-seek");
def f as fs.File init fs.open("demo-seek/log.txt.tmp", "write");
fs.writeString($f, "first line\nsecond line\nthird line\n");
fs.sync($f);                                 # the data
fs.close($f);
fs.rename("demo-seek/log.txt.tmp", "demo-seek/log.txt");
fs.syncDir("demo-seek");                     # the new name

def r as fs.File init fs.open("demo-seek/log.txt", "read");
io.printf("%s\n", fs.readLine($r));
def mark as int init fs.tell($r);            # start of the next line
io.printf("saved offset %d\n", $mark);
fs.seek($r, 0);
io.printf("%s\n", fs.readLine($r));
fs.seek($r, $mark);                          # resume where we were
io.printf("%s\n", fs.readLine($r));
fs.close($r);

fs.remove("demo-seek/log.txt");
fs.remove("demo-seek");

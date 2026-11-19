use io;

def status as int init 404;
match ($status) {
    when 200 { io.printf("ok\n"); }
    when 404, 410 { io.printf("gone\n"); }
    else { io.printf("other\n"); }
}

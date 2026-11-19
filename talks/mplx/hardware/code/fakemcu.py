# A fake microcontroller on a pseudo-terminal: answers a line protocol.
import os, sys, tty
master, slave = os.openpty()
tty.setraw(master)
link = sys.argv[1]
if os.path.lexists(link):
    os.remove(link)
os.symlink(os.ttyname(slave), link)
print("fake MCU on", os.ttyname(slave), "->", link, flush=True)
temp = 21.4
drop = int(sys.argv[2]) if len(sys.argv) > 2 else 0
asked = 0
buf = b""
while True:
    try:
        data = os.read(master, 256)
    except OSError:
        break
    buf += data
    while b"\n" in buf:
        line, buf = buf.split(b"\n", 1)
        cmd = line.strip().decode()
        print("got", repr(cmd), flush=True)
        if cmd == "PING":
            reply = "PONG"
        elif cmd == "TEMP?":
            asked += 1
            if drop and asked % drop == 0:
                continue  # busy: this request gets no answer
            reply = "TEMP %.1f" % temp
            temp += 0.3
        elif cmd in ("LED 0", "LED 1"):
            reply = "OK"
        elif cmd == "SLEEP":
            continue  # the MCU is busy: no answer at all
        else:
            reply = "ERR unknown command"
        os.write(master, (reply + "\r\n").encode())

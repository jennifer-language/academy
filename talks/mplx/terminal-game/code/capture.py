"""capture.py SESSION.json: run a terminal program in a pseudo-terminal, press
keys on a schedule and print what the screen shows, as plain text.

SESSION.json: {"cmd": [...], "env": {...}, "rows": 24, "cols": 80,
  "steps": [["key", "up"], ["sleep", 0.3], ["waitfor", "GO!"], ["snap", "a"]]}
"key" sends a character or up/down/left/right, "sleep" lets the program run,
"waitfor" waits until a text is on screen, "snap" prints the screen between
==== name ==== lines. The screen is printed once more at the end ("final").
Only the escape sequences the screen module writes are understood."""
import json, os, pty, re, select, sys, time, fcntl, termios, struct

cfg = json.load(open(sys.argv[1]))
rows, cols = cfg.get("rows", 24), cfg.get("cols", 80)
pid, fd = pty.fork()
if pid == 0:
    os.chdir(cfg.get("cwd", "."))
    env = dict(os.environ); env.update(cfg.get("env", {}))
    os.execvpe(cfg["cmd"][0], cfg["cmd"], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))

class Screen:
    def __init__(s):
        s.main = [[" "] * cols for _ in range(rows)]
        s.alt = [[" "] * cols for _ in range(rows)]
        s.g = s.main; s.x = s.y = 0; s.buf = ""
    def feed(s, data):
        s.buf += data
        i = 0; b = s.buf
        while i < len(b):
            c = b[i]
            if c == "\x1b":
                m = re.match(r"\x1b\[([?0-9;]*)([A-Za-z])", b[i:])
                if not m:
                    if len(b) - i < 16: break
                    i += 1; continue
                s.csi(m.group(1), m.group(2)); i += m.end(); continue
            if c == "\r": s.x = 0
            elif c == "\n": s.y = min(rows - 1, s.y + 1)
            elif c == "\b": s.x = max(0, s.x - 1)
            elif ord(c) >= 32:
                if s.x < cols: s.g[s.y][s.x] = c
                s.x += 1
            i += 1
        s.buf = b[i:]
    def csi(s, p, f):
        if f == "H":
            parts = [int(v) if v else 1 for v in p.split(";")] if p else [1, 1]
            s.y, s.x = parts[0] - 1, (parts[1] - 1 if len(parts) > 1 else 0)
        elif f == "J" and p == "2":
            for r in s.g: r[:] = [" "] * cols
        elif f == "K":
            s.g[s.y][:] = [" "] * cols
        elif f in "hl" and p == "?1049":
            if f == "h": s.saved = (s.x, s.y)
            else: s.x, s.y = s.saved
            s.g = s.alt if f == "h" else s.main
            if f == "h":
                for r in s.alt: r[:] = [" "] * cols
    def text(s):
        lines = ["".join(r).rstrip() for r in s.g]
        while lines and not lines[-1]: lines.pop()
        return "\n".join(lines)

scr = Screen(); raw = []
def pump(t):
    end = time.time() + t
    while True:
        left = end - time.time()
        if left <= 0: return True
        r, _, _ = select.select([fd], [], [], left)
        if r:
            try: d = os.read(fd, 65536)
            except OSError: return False
            if not d: return False
            raw.append(d); scr.feed(d.decode("utf-8", "replace"))
keys = {"up": "\x1b[A", "down": "\x1b[B", "right": "\x1b[C", "left": "\x1b[D"}
for st in cfg["steps"]:
    if st[0] == "key": os.write(fd, keys.get(st[1], st[1]).encode())
    elif st[0] == "sleep": pump(st[1])
    elif st[0] == "waitfor":
        while st[1] not in scr.text():
            if not pump(0.01): break
    elif st[0] == "snap": print("==== %s ====" % st[1]); print(scr.text())
pump(cfg.get("tail", 2.0))
print("==== final ====")
print(scr.text())

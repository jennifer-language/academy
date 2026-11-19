# snake.j - a small snake game for the terminal
use io;
use os;
use fs;
use convert;
use strings;
use lists;
use math;
use time;
use term;
use crc;
use encoding;
import "screen.j" as screen;
import "ringbuffer.j" as ringbuffer;
import "semver.j" as semver;

def const W as int init 26; # the field, inside the walls
def const H as int init 8;
def const TICK_MS as int init 150; # one step every 150 ms
def const SAVE_FILE as string init "snake.save";
def const MAGIC as string init "snake-save ";
def const SAVE_FORMAT as string init "1.0.0";
def const READS as string init "^1.0.0";

def struct Game {
    body as ringbuffer.RingBuffer,
    dx as int,
    dy as int,
    food as string,
    score as int,
    over as bool
};

# cell names a square of the field, "x,y"
func cell(x as int, y as int) {
    return convert.toString($x) + "," + convert.toString($y);
}

func cellX(c as string) {
    return convert.toInt(strings.split($c, ",")[0]);
}

func cellY(c as string) {
    return convert.toInt(strings.split($c, ",")[1]);
}

func placeFood(body as ringbuffer.RingBuffer) {
    def taken as list of string init ringbuffer.toList($body);
    def spot as string init "";
    repeat {
        $spot = cell(math.randInt(0, W - 1), math.randInt(0, H - 1));
    } until (not lists.contains($taken, $spot));
    return $spot;
}

func newGame() {
    def body as ringbuffer.RingBuffer init ringbuffer.new(3);
    for (def x in 2..5) {
        $body = ringbuffer.push($body, cell($x, 3));
    }
    def food as string init placeFood($body);
    return Game{body: $body, dx: 1, dy: 0, food: $food, score: 0, over: false};
}

# grow copies the body into a ring with one more slot
func grow(body as ringbuffer.RingBuffer) {
    def size as int init ringbuffer.capacity($body) + 1;
    def bigger as ringbuffer.RingBuffer init ringbuffer.new($size);
    for (def c in ringbuffer.toList($body)) {
        $bigger = ringbuffer.push($bigger, $c);
    }
    return $bigger;
}

# direction turns a key into a step [dx, dy]; [0, 0] for other keys
func direction(key as screen.Key) {
    def name as string init $key.name;
    if ($name == "char") {
        $name = $key.char;
    }
    match ($name) {
        when "up", "w" { return [0, -1]; }
        when "down", "s" { return [0, 1]; }
        when "left", "a" { return [-1, 0]; }
        when "right", "d" { return [1, 0]; }
    }
    return [0, 0];
}

func turn(g as Game, key as screen.Key) {
    def d as list of int init direction($key);
    def isTurn as bool init $d[0] != 0 or $d[1] != 0;
    def isReverse as bool init $d[0] == -$g.dx and $d[1] == -$g.dy;
    if ($isTurn and not $isReverse) {
        $g.dx = $d[0];
        $g.dy = $d[1];
    }
    return $g;
}

func step(g as Game) {
    def head as string init ringbuffer.last($g.body);
    def x as int init cellX($head) + $g.dx;
    def y as int init cellY($head) + $g.dy;
    def next as string init cell($x, $y);
    def eats as bool init $next == $g.food;
    def others as list of string init ringbuffer.toList($g.body);
    if (not $eats) {
        $others = $others[1..]; # the tail moves out of the way
    }
    def hitsWall as bool init $x < 0 or $x >= W or $y < 0 or $y >= H;
    if ($hitsWall or lists.contains($others, $next)) {
        $g.over = true;
        return $g;
    }
    if ($eats) {
        $g.score = $g.score + 1;
        $g.body = grow($g.body);
    }
    $g.body = ringbuffer.push($g.body, $next); # full: the tail drops
    if ($eats) {
        $g.food = placeFood($g.body);
    }
    return $g;
}

# plot puts a glyph on a cell; the walls shift the field by one
func plot(buf as screen.Buffer, c as string, glyph as string) {
    return screen.set($buf, cellX($c) + 1, cellY($c) + 1, $glyph);
}

func draw(g as Game, best as int) {
    def buf as screen.Buffer init screen.newScreen(H + 3, W + 2);
    $buf = screen.hline($buf, 0, 0, W + 2, "-");
    $buf = screen.hline($buf, 0, H + 1, W + 2, "-");
    $buf = screen.vline($buf, 0, 1, H, "|");
    $buf = screen.vline($buf, W + 1, 1, H, "|");
    $buf = plot($buf, $g.food, "*");
    for (def c in ringbuffer.toList($g.body)) {
        $buf = plot($buf, $c, "o");
    }
    $buf = plot($buf, ringbuffer.last($g.body), "@");
    $buf = screen.text($buf, 1, H + 2, io.sprintf("score %d", $g.score));
    $buf = screen.text($buf, 11, H + 2, io.sprintf("best %d", $best));
    $buf = screen.text($buf, 20, H + 2, "q quits");
    if ($g.over) {
        $buf = screen.text($buf, W // 2 - 4, H // 2, " GAME OVER ");
    }
    return $buf;
}

func isQuit(key as screen.Key) {
    match ($key.name) {
        when "eof", "ctrl-c", "escape" { return true; }
        when "char" { return $key.char == "q"; }
    }
    return false;
}

# play runs one game and returns its score
func play(best as int, interactive as bool) {
    def input as screen.Input init screen.startInput();
    def g as Game init newGame();
    def shown as screen.Buffer init draw($g, $best);
    io.printf("%s%s", screen.clear(), screen.render($shown));
    def quit as bool init false;
    repeat {
        time.sleep(time.fromMilliseconds(TICK_MS));
        def key as screen.Key init screen.pollKey($input);
        $quit = isQuit($key);
        if (not $quit) {
            $g = step(turn($g, $key));
            def frame as screen.Buffer init draw($g, $best);
            io.printf("%s", screen.diff($shown, $frame));
            $shown = $frame;
        }
    } until ($quit or $g.over);
    if ($g.over and $interactive) {
        time.sleep(time.fromMilliseconds(500));
        def ended as bool init false;
        while (screen.hasKey($input)) { # drop keys typed too late
            $ended = $ended or screen.pollKey($input).name == "eof";
        }
        if (not $ended) {
            screen.waitKey($input); # any key leaves
        }
    }
    return $g.score;
}

func checksum(text as string) {
    def data as bytes init convert.bytesFromString("utf-8", $text);
    return encoding.toText("hex", crc.compute("crc32", $data));
}

func saveBest(best as int) {
    def text as string init MAGIC + SAVE_FORMAT + "\n";
    $text = $text + "best " + convert.toString($best) + "\n";
    $text = $text + "crc " + checksum($text) + "\n";
    fs.writeString(SAVE_FILE, $text);
}

func saveError(message as string) {
    return Error{kind: "save", message: $message};
}

func loadBest() {
    if (not fs.exists(SAVE_FILE)) {
        return 0;
    }
    def raw as string init fs.readString(SAVE_FILE);
    def lines as list of string init strings.split($raw, "\n");
    if (len($lines) != 4 or not strings.startsWith($raw, MAGIC)) {
        throw saveError("not a snake save file");
    }
    def version as string init $lines[0][len(MAGIC)..];
    if (not semver.satisfies($version, READS)) {
        throw saveError("unknown save format " + $version);
    }
    def text as string init $lines[0] + "\n" + $lines[1] + "\n";
    if ($lines[2] != "crc " + checksum($text)) {
        throw saveError("checksum mismatch, file damaged or edited");
    }
    return convert.toInt($lines[1][5..]);
}

def best as int init 0;
try {
    $best = loadBest();
} catch (e) {
    if ($e.kind != "save") {
        throw $e;
    }
    io.eprintf("snake: %s; best score starts at 0\n", $e.message);
}
if (os.hasEnv("SNAKE_SEED")) {
    math.randSeed(convert.toInt(os.getEnv("SNAKE_SEED")));
}

def score as int init 0;
if (os.isTerminal("stdin")) {
    def state as term.State init screen.begin();
    defer screen.end($state);
    $score = play($best, true);
} else {
    $score = play($best, false); # moves from a pipe or a file
    io.printf("%s", screen.moveTo(0, H + 3));
}
if ($score > $best) {
    saveBest($score);
    io.printf("new best score: %d\n", $score);
} else {
    io.printf("score %d, best %d\n", $score, $best);
}

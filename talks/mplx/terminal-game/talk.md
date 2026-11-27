---
theme: ember
ratio: 16:9
transition: slide
---

# A terminal game in Jennifer

![Jennifer](jennifer-logo.png)

A small snake game, one idea at a time: keys, frames, a loop, a ring buffer
and a high score file you can trust.

November 2026, by [@mplx](https://github.com/mplx).\
Based on **Jennifer 0.27.0**

<!-- notes:
Games are a fun way to learn programming, because you see every mistake at
once: the snake runs through a wall, or the screen flickers. In this talk we
write a complete snake game for the terminal in about 250 lines of Jennifer.
You need to know variables, if, loops and functions; everything else we meet on
the way. Every frame and every output on these slides comes from a real run.
-->

---

## What we build

```text
----------------------------
|                  oo@     |
|                  o       |
|                          |
|              *           |
|                          |
----------------------------
 score 1   best 0   q quits
```

Arrow keys or `w` `a` `s` `d` steer, `q` quits: `jennifer run snake.j`

<!-- notes:
This is a real frame from the game, captured from a terminal, with three empty
rows cut out to fit the slide. The at sign is the head of the snake, the small
o letters are its body, and the star is food. Eat the food and the snake grows
by one and you score a point. Hit a wall or yourself and the game is over. The
best score is kept in a file between games.
-->

---

## A game is a loop

| Step | What happens | Jennifer |
| --- | --- | --- |
| wait | let a little time pass | `time.sleep` |
| input | was a key pressed? never wait for one | `screen.pollKey` |
| update | move the snake, check for crashes | our `step` |
| draw | build the next frame, send the changes | `screen.diff` |

Every 150 ms, round and round, until the game is over.

<!-- notes:
Almost every game has this shape. A text program waits for you to type a line;
a game cannot do that, because the snake must keep moving whether you press a
key or not. So the loop looks at the keyboard, takes a key if there is one,
moves the world one step and draws it. One trip round the loop is called a
tick. Our snake ticks every 150 milliseconds, about seven times a second.
-->

---

## Raw keys with the term library

```jennifer excerpt
def state as term.State init term.makeRaw("stdin");
defer term.restore($state);
io.printf("press any key when you see GO!\r\n");
# wait 1 to 3 seconds; a key pressed before GO! is a false start
def early as int init term.readByteTimeout(math.randInt(1000, 3000));
if ($early != -2) {
    io.printf("too early!\r\n");
```

From `reaction.j`, a reaction timer in 29 lines.

<!-- notes:
Normally the terminal collects a whole line and hands it over when you press
Enter. A game wants every key the moment it is pressed, without it being
printed. That is raw mode, and term.makeRaw switches it on. The defer line
makes sure the terminal is switched back however the program ends. In raw mode
a newline does not return to the start of the line, so we print backslash r
backslash n.
-->

---

## readByteTimeout: three kinds of answer

| Result | Meaning |
| --- | --- |
| `0` to `255` | a byte: the key that was pressed |
| `-1` | end of input: nothing more will come |
| `-2` | the time ran out, no key |

```text
press any key when you see GO!          press any key when you see GO!
too early!                              GO!
                                        264 ms
```

<!-- notes:
term.readByte waits for ever; readByteTimeout waits at most the number of
milliseconds you give it. The reaction timer uses both outcomes: during the
random wait a timeout is good news, and a byte means a false start. After GO!
it measures how long the key took. Both runs were driven by a script that
pressed the space bar, once too early and once a quarter second after GO!.
-->

---

## The screen module does the rest

```jennifer excerpt
if (os.isTerminal("stdin")) {
    def state as term.State init screen.begin();
    defer screen.end($state);
    $score = play($best, true);
} else {
    $score = play($best, false); # moves from a pipe or a file
    io.printf("%s", screen.moveTo(0, H + 3));
}
```

`begin`: raw mode, alternate screen, cursor hidden. `end` undoes it all.

<!-- notes:
The screen module is written in Jennifer on top of term. screen.begin turns
on raw mode, switches to the alternate screen, the one editors use, so your
shell history is still there afterwards, hides the cursor and clears. end
puts it all back, again in a defer. When input does not come from a terminal,
we skip raw mode and still play; we will use that later to replay a game from
a file.
-->

---

## Keys without waiting

```jennifer excerpt
def input as screen.Input init screen.startInput();
...
def key as screen.Key init screen.pollKey($input);
```

| `key.name` | when |
| --- | --- |
| `"char"` | a printable key, the letter is in `key.char` |
| `"up"` `"down"` `"left"` `"right"` | arrow keys |
| `"escape"` `"ctrl-c"` `"enter"` ... | the other named keys |
| `"none"` | no key is waiting right now |
| `"eof"` | input has ended |

<!-- notes:
startInput starts a background task that reads keys and puts them in a queue.
pollKey takes the next key from that queue, or a key named none if the queue
is empty, so it never waits. An arrow key arrives as three bytes, escape,
bracket and a letter; the module turns them into one key called up, down,
left or right. In raw mode control C is just a key, so we handle it ourselves.
-->

---

## One key per tick, no U-turns

```jennifer excerpt
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
```

<!-- notes:
direction turns a key into a step: up is zero, minus one, because rows count
downwards. A snake must not turn back into its own neck, so a key that points
the opposite way is ignored. We take only one key per tick: press up and
right quickly and the snake turns twice, on two ticks, instead of the second
key silently replacing the first.
-->

---

## The field is a buffer of cells

```jennifer excerpt
func draw(g as Game, best as int) {
    def buf as screen.Buffer init screen.newScreen(H + 3, W + 2);
    $buf = screen.hline($buf, 0, 0, W + 2, "-");
    $buf = screen.vline($buf, 0, 1, H, "|");
    ...
    $buf = plot($buf, $g.food, "*");
    for (def c in ringbuffer.toList($g.body)) {
        $buf = plot($buf, $c, "o");
    }
    $buf = plot($buf, ringbuffer.last($g.body), "@");
```

<!-- notes:
A screen.Buffer is a grid of cells, rows and columns, counted from zero at the
top left. Each drawing call returns the changed buffer, so we assign it back.
Inside a function that is cheap: Jennifer changes the grid in place. We draw
the walls with dashes and bars rather than screen.box, whose box-drawing
characters look nicer on screen but could not be printed on these slides.
-->

---

## Draw everything, send only the changes

```jennifer excerpt
def frame as screen.Buffer init draw($g, $best);
io.printf("%s", screen.diff($shown, $frame));
$shown = $frame;
```

| Output | Bytes |
| --- | --- |
| first frame, `screen.render` | 376 |
| one tick, `screen.diff` | 15 |

```text
ESC[5;4H ESC[5;6Ho@
```

<!-- notes:
We build each frame from scratch, which keeps the drawing code simple, and
let diff work out what changed since the frame on screen. When the snake moves
one step, two things change: the tail cell becomes a space, and the old head
becomes body while a new head appears. That is two cursor moves and three
characters, fifteen bytes, measured from the real output. No flicker.
-->

---

## The snake is a ring buffer

```jennifer excerpt
def body as ringbuffer.RingBuffer init ringbuffer.new(3);
for (def x in 2..5) {
    $body = ringbuffer.push($body, cell($x, 3));
}
```

| Cells, oldest first | |
| --- | --- |
| `"2,3"` `"3,3"` `"4,3"` | tail ... head, the ring is full |
| `"3,3"` `"4,3"` `"5,3"` | after `push("5,3")`: the tail fell off |

<!-- notes:
A ring buffer holds a fixed number of entries. When it is full, push drops
the oldest. That is exactly how a snake moves: a new head in front, the last
piece of tail gone. ringbuffer holds strings, so a cell is written as x comma
y. last gives the head, toList all cells from tail to head. Moving costs one
push, however long the snake gets.
-->

---

## Growing: a bigger ring

```jennifer excerpt
# grow copies the body into a ring with one more slot
func grow(body as ringbuffer.RingBuffer) {
    def size as int init ringbuffer.capacity($body) + 1;
    def bigger as ringbuffer.RingBuffer init ringbuffer.new($size);
    for (def c in ringbuffer.toList($body)) {
        $bigger = ringbuffer.push($bigger, $c);
    }
    return $bigger;
}
```

<!-- notes:
The capacity of a ring buffer never changes, so to grow the snake we copy it
into a ring with one more slot. The next push then finds a free slot and drops
nothing: the tail stays where it is and the snake is one cell longer. Copying
costs a little, but it happens only when the snake eats, not on every tick.
-->

---

## One step: walls, yourself, food

```jennifer excerpt
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
```

<!-- notes:
x and y are the new head: the old head plus the direction. Outside the field
is a wall. Running into your own body ends the game too, with one subtle
point: on a normal step the tail moves away in the same tick, so chasing your
own tail closely is allowed. That is why the tail is left out unless the snake
eats. If it does eat, the score goes up and grow runs before the push.
-->

---

## Food in a random place

```jennifer excerpt
func placeFood(body as ringbuffer.RingBuffer) {
    def taken as list of string init ringbuffer.toList($body);
    def spot as string init "";
    repeat {
        $spot = cell(math.randInt(0, W - 1), math.randInt(0, H - 1));
    } until (not lists.contains($taken, $spot));
    return $spot;
}
```

`SNAKE_SEED=7` calls `math.randSeed(7)`: the same food every game.

<!-- notes:
math.randInt gives a whole number between two limits, both included. We try
random cells until one is not under the snake. math.randSeed makes the random
numbers repeat, which is how the frames on these slides can be reproduced:
with the same seed the food always appears in the same places. For a real game
leave the seed out and every game is different.
-->

---

## The loop

```jennifer excerpt
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
```

<!-- notes:
Here are the four steps from the start of the talk, in eleven lines. The
sleep sets the speed: make TICK_MS smaller and the game gets harder. A real
game would subtract the time drawing took, but at seven ticks a second this is
smooth enough. isQuit says yes for q, Escape, control C and the end of input.
-->

---

## Real frames, in a real terminal

```text
----------------------------    ----------------------------
|                   *      |    |                      ooo@|
|          oo@             |    |                          |
|                          |    |                          |
|                          |    |         GAME OVER        |
----------------------------    ----------------------------
 score 0   best 0   q quits      score 1   best 0   q quits
```

Up, right, ... and straight into the wall.

<!-- notes:
These frames were captured from a pseudo-terminal: a small script started the
game, pressed the arrow keys with pauses in between, and read back what the
screen showed. Rows of empty field are cut. On the left the snake has turned
up and right, on the right it has eaten one star and run into the right wall.
The game then waits for any key before it leaves.
-->

---

## End of input, and replaying a game

```text
$ printf 'ab' | jennifer run eof-poll.j
0: char
1: char
2: eof
3: none
4: none
```

`jennifer run snake.j < moves.txt`: one letter per tick, `x` goes straight.

<!-- notes:
When input ends, pollKey hands out one key named eof, then none for ever. In
Jennifer 0.26.0, waitKey after that eof waits for ever too, so the game
remembers whether it saw eof and never waits for a key that cannot come. This
lets us play from a file: a moves file is consumed one letter per tick, and with
a fixed seed a replay ends with the same frame every time, which is handy for
testing.
-->

---

## Saving the high score

```jennifer excerpt
func saveBest(best as int) {
    def text as string init MAGIC + SAVE_FORMAT + "\n";
    $text = $text + "best " + convert.toString($best) + "\n";
    $text = $text + "crc " + checksum($text) + "\n";
    fs.writeString(SAVE_FILE, $text);
}
```

```text
snake-save 1.0.0
best 4
crc bc15eaa4
```

<!-- notes:
The save file is plain text, so you can look at it. The first line says what
it is and which version of the format; the second holds the score; the third
a CRC-32 checksum of the first two lines, from crc.compute, written as hex.
If a single character of the first two lines changes, the checksum no longer
matches. This is the real file after the replayed game.
-->

---

## Loading it, carefully

```jennifer excerpt
def version as string init $lines[0][len(MAGIC)..];
if (not semver.satisfies($version, READS)) {
    throw saveError("unknown save format " + $version);
}
def text as string init $lines[0] + "\n" + $lines[1] + "\n";
if ($lines[2] != "crc " + checksum($text)) {
    throw saveError("checksum mismatch, file damaged or edited");
}
```

```text
snake: checksum mismatch, file damaged or edited; best score starts at 0
snake: unknown save format 2.0.0; best score starts at 0
```

<!-- notes:
First the version: READS is caret 1.0.0, so any 1.x file is fine, but a file
from a future version 2 is refused rather than misread. Then the checksum. The
two messages are real: the first after changing best 4 to best 99 in an editor,
the second with a version 2 header. A CRC catches accidents and casual edits,
not a cheater who recomputes it; for that you would need a secret key.
-->

---

## Over to you

- Speed up a little with every star: `TICK_MS` from the score
- Keep the last five scores: another `ringbuffer`, saved as more lines
- Colour: `screen.textColor` paints the snake green
- Two players on one keyboard: arrows and `w` `a` `s` `d`

The full game: [demo-jsnake](https://github.com/jennifer-language/demo-jsnake),
multiplayer snake over the network, with CPU opponents.

All programs, the moves file and the capture script are in this talk's
`code/` folder. More talks: [academy.jennifer-lang.dev](https://academy.jennifer-lang.dev/)

<!-- notes:
The game is small on purpose, so every one of these ideas is an afternoon.
A history of scores is a nice second use of the ring buffer. If you add a
field to the save file, raise the format to 1.1.0, so an older game can still
tell whether it may read it. Send your version to the academy as a talk of
your own: that is the best way to learn it properly. demo-jsnake is where this
game grows up: players find each other by UDP broadcast, play over TCP or UDP,
and empty seats are filled by CPU opponents at four levels.
-->

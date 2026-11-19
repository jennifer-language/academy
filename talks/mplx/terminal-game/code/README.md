# Code for "A terminal game in Jennifer"

Every program runs on the released Jennifer 0.26.0 (`jennifer`, the default
binary: the `term` library is not in `jennifer-tiny`). Run them from this
folder; nothing else needs installing. `snake.j` writes `snake.save` here.

| File | Slides | Run |
| --- | --- | --- |
| `snake.j` | the whole talk | `jennifer run snake.j` in a terminal (arrows or w a s d, q quits) |
| `snake.j` with a seed | Food in a random place | `SNAKE_SEED=7 jennifer run snake.j` (the same food every game) |
| `moves.txt` | End of input, Saving the high score | `SNAKE_SEED=7 jennifer run snake.j < moves.txt` (one letter per tick, `x` goes straight) |
| `reaction.j` | Raw keys with the term library, readByteTimeout | `jennifer run reaction.j` in a terminal |
| `eof-poll.j` | End of input | `printf 'ab' \| jennifer run eof-poll.j` |
| `eof-wait.j` | End of input (notes) | `printf 'ab' \| timeout 5 jennifer run eof-wait.j` (hangs after `eof` on 0.26.0, so the timeout ends it) |
| `capture.py` | the captured frames | `python3 capture.py snake-session.json` |

`capture.py` (Python 3, standard library only, Linux or macOS) starts a program
in a pseudo-terminal, presses keys on a schedule and prints the screen as text.
The sessions behind the slides:

- `snake-session.json`: a game played with arrow keys (Real frames, What we build)
- `replay-session.json`: the `moves.txt` replay (the score 4 save file)
- `reaction-session.json`: a key pressed 0.26 s after GO!

Frames depend on timing, so a rerun of `snake-session.json` can differ by a
cell or two; the replay is the same every time. To try the save file checks,
edit `snake.save` (change the score, or the version to `2.0.0`) and start the
game again.

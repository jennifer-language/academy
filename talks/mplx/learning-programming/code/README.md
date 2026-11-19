# Learning programming with Jennifer: the code

Every program from the slides, one file per slide. They need no server, no
decks and no setup beyond Jennifer 0.26.0, and run from this folder.

- `hello.j`: "A program is a list of steps". Run: `jennifer run hello.j`
- `variables.j`: "Variables are named boxes", prints `Ada is 37`.
  Run: `jennifer run variables.j`
- `sums.j`: "Doing sums", prints 13, 3.5, 3 and 1. Run: `jennifer run sums.j`
- `decisions.j`: "Making decisions", prints `pleasant`; change the temperature
  to see the other answers. Run: `jennifer run decisions.j`
- `questions.j`: the comparisons and the words `and`, `or`, `not` from
  "Questions with yes or no answers", with sample values.
  Run: `jennifer run questions.j`
- `loops.j`: "Doing it again: loops", the countdown and three rounds.
  Run: `jennifer run loops.j`
- `lists.j`: "Lists keep things in order". The slide shows the first line;
  the loop then prints the three fruits. Run: `jennifer run lists.j`
- `maps.j`: "Maps look things up by name". Run: `jennifer run maps.j`
- `functions.j`: "Functions give a name to steps", prints
  `13.50 square metres`. Run: `jennifer run functions.j`
- `mistakes.sh`: "Mistakes become messages". Writes `typo.j` and `check.j`
  to a temporary directory and runs them, because programs with mistakes
  cannot be kept here (every `.j` file in this folder must pass
  `jennifer lint`). The path in each message is that temporary directory,
  not `/home/ada`. Run: `sh mistakes.sh`
- `report.j`: "Putting it together", prints Ada with an A and Alan with a B.
  Run: `jennifer run report.j`
- `repl.sh` with `repl.txt`: "Try things in the REPL". Pipes the four lines
  of `repl.txt` into `jennifer repl`; piped input is not echoed, so the
  answers follow the `>>>` prompts without the typed lines. Run: `sh repl.sh`

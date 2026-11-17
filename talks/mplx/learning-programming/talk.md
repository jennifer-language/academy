---
theme: grimoire
ratio: 16:9
transition: fade
---

# Learning programming with Jennifer

![Jennifer](jennifer-logo.png)

Your first steps in programming: values, variables, decisions, loops, lists and
functions, one small program at a time.

by [@mplx](https://github.com/mplx)

<!-- notes:
This talk is for people who have never written a program. Every slide has one
idea and one small program, and every program on these slides was run before
the talk, so what you see is what the computer really answers. You need no
maths beyond counting, and no other language. If you can follow a recipe, you
can follow a program: it is a list of steps, done one after the other.
-->

---

## A program is a list of steps

```jennifer
use io;

io.printf("Hello, world!\n");
```

```text
$ jennifer run hello.j
Hello, world!
```

<!-- notes:
Save these two lines in a file called hello.j and run it with jennifer run.
The first line asks for the io library, the part of Jennifer that talks to the
screen. The second line prints a greeting; the backslash n at the end starts a
new line. The computer reads the file from top to bottom and does each step in
turn. Every line that does something ends with a semicolon, like a sentence
ends with a full stop.
-->

---

## Values have types

| Type | Examples | What it holds |
| --- | --- | --- |
| `int` | `42`, `-7`, `0` | whole numbers |
| `float` | `3.14`, `0.5` | numbers with a fractional part |
| `string` | `"Ada"`, `"hello"` | text, in quotes |
| `bool` | `true`, `false` | yes or no |

<!-- notes:
Everything a program works with is a value, and every value has a type. The
type says what kind of thing it is and what you can do with it: you can add two
numbers, you can join two pieces of text, and you can ask whether something is
true. Jennifer never guesses a type for you, which means it also never guesses
wrong. Keep these four in mind; most programs are built from them.
-->

---

## Variables are named boxes

```jennifer
use io;

def name as string init "Ada";
def age as int init 36;
$age = $age + 1;
io.printf("{$name} is {$age}\n");
```

```text
Ada is 37
```

<!-- notes:
A variable is a box with a name and a type. def name as string init Ada makes
a box called name that holds text, and puts Ada into it. To read or change a
box you write its name with a dollar sign in front. The third line takes the
age out, adds one, and puts the result back. Inside double quotes, curly braces
drop a value into the text.
-->

---

## Doing sums

```jennifer
use io;

io.printf("%d\n", 7 + 3 * 2);
io.printf("%f\n", 7 / 2);
io.printf("%d\n", 7 // 2);
io.printf("%d\n", 7 % 2);
```

```text
13
3.5
3
1
```

<!-- notes:
Arithmetic works as in school: multiplication before addition, so seven plus
three times two is thirteen. One slash is true division and always gives a
number with a fractional part, three point five. Two slashes divide and drop
the remainder, giving three, and the percent sign gives that remainder, one.
The percent d and percent f in printf say where an int or a float goes in the
text.
-->

---

## Making decisions

```jennifer
use io;

def temperature as int init 23;
if ($temperature > 30) {
    io.printf("hot\n");
} elseif ($temperature > 15) {
    io.printf("pleasant\n");
} else {
    io.printf("cold\n");
}
```

<!-- notes:
An if runs a block of code only when its condition is true. The conditions are
tried from the top: is it above thirty? No. Is it above fifteen? Yes, so the
program prints pleasant and skips the rest. Exactly one of the three blocks
runs. The curly braces mark where each block starts and ends. Change the
temperature and run it again to see the other answers.
-->

---

## Questions with yes or no answers

| You write | It asks |
| --- | --- |
| `$a == $b` | are they equal? |
| `$a != $b` | are they different? |
| `$a < $b`, `$a >= $b` | smaller? at least as big? |
| `$hungry and $awake` | are both true? |
| `$rain or $snow` | is at least one true? |
| `not $done` | is it false? |

<!-- notes:
A condition is a question whose answer is a bool, true or false. Two equals
signs compare; a single equals sign stores a value, so do not mix them up. The
words and, or and not combine answers the way they do in English: and needs
both to be true, or needs at least one, and not turns true into false. Other
languages use symbols for these; Jennifer uses the words you would say aloud.
-->

---

## Doing it again: loops

```jennifer
use io;

def n as int init 3;
while ($n > 0) {
    io.printf("%d... ", $n);
    $n = $n - 1;
}
io.printf("lift-off!\n");

for (def i in 1..4) {
    io.printf("round %d\n", $i);
}
```

<!-- notes:
A while loop repeats its block as long as the condition stays true. Here it
counts down from three; each time round, n gets one smaller, and when it reaches
zero the loop stops and the program prints lift-off. The for loop below counts
for you: one dot dot four means the numbers from one up to, but not including,
four. So it runs three rounds, numbered one, two and three.
-->

---

## Lists keep things in order

```jennifer
use io;

def fruits as list of string init ["apple", "pear"];
$fruits[] = "plum";
io.printf("%d fruits, the first is %s\n", len($fruits), $fruits[0]);
for (def f in $fruits) {
    io.printf("- %s\n", $f);
}
```

```text
3 fruits, the first is apple
```

<!-- notes:
A list holds many values of one type, in order. Empty square brackets after
the name add a value at the end. len counts the values. Each value has a
position, counted from zero, so fruits zero is the first one, apple. A for
loop over a list visits every value in turn, which is the most common way to
work through a list: here it prints all three fruits, one per line.
-->

---

## Maps look things up by name

```jennifer
use io;

def ages as map of string to int init {"Ada": 36, "Alan": 41};
$ages["Grace"] = 85;
for (def who in $ages) {
    io.printf("%s: %d\n", $who, $ages[$who]);
}
```

```text
Ada: 36
Alan: 41
Grace: 85
```

<!-- notes:
A map is like a phone book: you look a value up by its key instead of by its
position. This one maps names, which are strings, to ages, which are ints.
Writing to a key that is not there yet adds it. A for loop over a map visits
the keys in the order they were added, and with the key you read the value. Use
a list when order matters and a map when names matter.
-->

---

## Functions give a name to steps

```jennifer
use io;

func area(width as float, height as float) {
    return $width * $height;
}

def room as float init area(4.5, 3.0);
io.printf("%f|prec=2 square metres\n", $room);
```

```text
13.50 square metres
```

<!-- notes:
A function is a recipe with a name. area takes two numbers, the width and the
height, and hands back their product with return. Once it is written you use
it by name, as often as you like, with different numbers each time. Functions
keep a program short and readable: instead of the same three lines in five
places, you write them once and call them. The bar prec two prints two decimals.
-->

---

## Mistakes become messages

```text
$ jennifer run typo.j
typo.j: parse error at /home/ada/typo.j:4:19: undefined variable "totl"
  io.printf("%d\n", $totl);
                    ^
```

```text
$ jennifer run check.j
check.j: runtime error at /home/ada/check.j:2:5: `if` condition must be bool, got int
  if ($count) {
      ^
```

<!-- notes:
Everybody makes mistakes, and the computer is very literal. Jennifer tells you
what went wrong, in which file, on which line and in which column, and points
at the spot. The first message is a typo in a variable name, found before the
program even starts. The second asks an if a question that is not yes or no.
Read the message, look at the arrow, fix the line, run again. That loop is
programming.
-->

---

## Putting it together

```jennifer
use io;
func grade(points as int) {
    if ($points >= 90) {
        return "A";
    } elseif ($points >= 50) {
        return "B";
    }
    return "F";
}
def scores as map of string to int init {"Ada": 95, "Alan": 78};
for (def who in $scores) {
    io.printf("%s|pad=6 %s\n", $who, grade($scores[$who]));
}
```

<!-- notes:
Here everything meets in one program: a function with decisions inside, a map
of names to points, and a loop that prints a small report. It prints Ada with
an A and Alan with a B. The bar pad six keeps the columns lined up. Try to
change it: add a student who fails, add a grade C for seventy points and up, or
count how many passed.
-->

---

## Try things in the REPL

```text
$ jennifer repl
>>> def x as int init 6 * 7;
>>> $x;
42
>>> $x > 40;
true
>>> "Hello, " + "Ada";
"Hello, Ada"
```

<!-- notes:
You do not need a file to try an idea. jennifer repl starts an interactive
session: type a line, press enter, and see the answer at once. Definitions are
kept, so you can build something up step by step. The REPL is the best place
to check what an operator does or how a value looks before you write it into a
program. Leave it with :quit or Ctrl-D.
-->

---

## Where to go next

- The user guide: [docs.jennifer-lang.dev](https://docs.jennifer-lang.dev/)
- Install Jennifer: [jennifer-lang.dev](https://jennifer-lang.dev/)
- The next talk: *Jennifer for coders*, in the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
That is the whole toolbox of a first course: values and types, variables,
sums, decisions, loops, lists, maps and functions. The user guide explains
each of them in more depth, with exercises. Once these feel familiar, the talk
Jennifer for coders shows the rest of the language: structs, errors, modules,
tests and running things at the same time.
-->

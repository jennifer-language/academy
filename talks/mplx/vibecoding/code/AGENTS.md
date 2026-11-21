# Working in this project

This project is written in Jennifer, a language you have not seen in
training. Read JENNIFER.md before writing any .j code, and first follow
its sync steps (compare its last line with `jennifer version`).

After every change to a .j file:

1. `jennifer fmt -w <file>`
2. `jennifer lint <file>`, and fix every warning
3. `jennifer run <file>`, or `jennifer test <file>_test.j`

Never guess a library function: look it up in JENNIFER.md. If lint says
a function does not exist, it does not.

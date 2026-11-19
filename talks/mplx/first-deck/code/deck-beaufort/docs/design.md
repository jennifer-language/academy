<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Design

## Scope

One function, from km/h to the Beaufort force. Other units are the
caller's conversion; descriptions of each force are left out.

## Decisions

- The limits are the lowest speed of forces 1 to 12, in whole km/h, one
  private constant; a speed on a limit belongs to the force above it.
- Speeds are `int`: the scale's own limits are whole numbers.

## Errors

A negative speed throws `Error{kind: "beaufort"}`. Nothing else is thrown.

## Security and limits

No input beyond one integer; no caps needed.

## Testing and validation

The overlay checks calm, both sides of a limit, the top of the scale and
the error.

## Known limitations and open questions

None.

## Dependencies on the interpreter

Jennifer 0.26.0 or newer; pure, so it also runs on `jennifer-tiny`.

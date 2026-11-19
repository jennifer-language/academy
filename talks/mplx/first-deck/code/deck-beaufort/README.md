# @mplx/beaufort

[![test](https://github.com/mplx/deck-beaufort/actions/workflows/test.yml/badge.svg)](https://github.com/mplx/deck-beaufort/actions/workflows/test.yml)
[![Documentation](https://img.shields.io/badge/docs-github%20pages-blue)](https://mplx.github.io/deck-beaufort/)
[![release](https://img.shields.io/github/v/release/mplx/deck-beaufort)](https://github.com/mplx/deck-beaufort/releases/latest)

Turns a wind speed into its Beaufort force for a
[Jennifer](https://jennifer-lang.dev/) program.

**[Documentation](https://mplx.github.io/deck-beaufort/)**

## Install

```sh
jvc add @mplx/beaufort
```

This vendors the deck to `vendor/<scope>/beaufort/`. Without `jvc`, unpack the
`src/` subtree of a release archive (`<scope>-beaufort-<version>.tar.gz`) there.

## Usage

```jennifer
import "@mplx/beaufort/" as beaufort;

io.printf("force %d\n", beaufort.force(45));
```

## Requirements

Jennifer 0.26.0 or newer. Pure Jennifer, no capabilities; runs on
`jennifer-tiny` too.

## Development

```sh
tools/check-all.sh                   # the full gate, as CI runs it
jennifer test src/beaufort_test.j      # the test overlay
tools/check-docs.sh                  # docs against the code
tools/pack.sh dist                   # build the release archive
```

## Licence

LGPL-3.0-only, see [LICENSE](LICENSE). Copyright (C) 2026 mplx &lt;mplx@jennifer-lang.dev&gt;.

`tools/check-headers.sh` checks every source file's SPDX header against
`deck.toml`.

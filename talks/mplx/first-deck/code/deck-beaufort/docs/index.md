<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# @mplx/beaufort

Turns a wind speed in km/h into its Beaufort force, 0 (calm) to 12
(hurricane), so a weather report does not need its own table.

## Conventions

Snippets assume this import:

```jennifer
import "@mplx/beaufort/" as beaufort;

io.printf("force %d\n", beaufort.force(45));
```

Errors: a negative speed throws `Error{kind: "beaufort"}`.

<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# beaufort cheatsheet

Every export of `@mplx/beaufort`.

```jennifer
import "@mplx/beaufort/" as beaufort;
```

## Force

| Function | Returns | Does |
|---|---|---|
| `force(kmh)` | `int` | the Beaufort force, 0 to 12, of a wind speed in km/h; throws kind `"beaufort"` for a negative speed |

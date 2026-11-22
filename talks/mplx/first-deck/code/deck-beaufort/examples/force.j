#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * The force of a few wind speeds: jennifer run examples/force.j
 */

use io;

import "../src/beaufort.j" as beaufort;

for (def kmh in [0, 10, 45, 120]) {
    io.printf("%d km/h: force %d\n", $kmh, beaufort.force($kmh));
}

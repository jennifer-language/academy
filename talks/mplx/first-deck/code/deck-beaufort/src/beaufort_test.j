# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * White-box tests for the entry module: jennifer test src/beaufort_test.j
 */
use testing;

func testCalm() {
    testing.assertEqual(force(0), 0);
}

func testLimitsBelongToTheForceAbove() {
    testing.assertEqual(force(38), 5);
    testing.assertEqual(force(39), 6);
}

func testHurricaneIsTheTop() {
    testing.assertEqual(force(118), 12);
    testing.assertEqual(force(300), 12);
}

func testNegativeSpeedThrows() {
    testing.assertThrowsArgs("force", [-1], "beaufort");
}

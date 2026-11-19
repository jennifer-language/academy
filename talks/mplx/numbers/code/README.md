# Numbers: the code

The programs behind the slides. They need no server and run with Jennifer
0.26.0 from this folder. Only `money.j` and `allocate.j` use a deck: run
`jvc install` once here first, which reads `deck.toml` and vendors
`@deckyard/money` into `vendor/`.

- `floats.j`: `0.1 + 0.2`, a float invoice and float rounding
  ("Floats cannot count money").
  Run: `jennifer run floats.j`
- `decimal.j`: the same invoice with `decimal`, rounded once
  ("decimal: exact, and you say when to round").
  Run: `jennifer run decimal.j`
- `modes.j`: rounding modes, division with and without a scale
  ("Rounding modes and division").
  Run: `jennifer run modes.j`
- `perline.j`: VAT rounded per line or on the total, splitting 100 in three
  ("Round per line, or on the total?").
  Run: `jennifer run perline.j`
- `money.j`: `@deckyard/money` amounts in minor units, a sum and an exchange
  ("@deckyard/money: minor units and a code").
  Needs: `jvc install`. Run: `jennifer run money.j`
- `allocate.j`: `allocateTo` and `allocate` without losing a cent, mixing
  currencies throws ("money.allocate: no cent lost").
  Needs: `jvc install`. Run: `jennifer run allocate.j`
- `grouping.j`: an amount with a group separator and a decimal mark
  ("Money for a reader: grouping and the mark").
  Run: `jennifer run grouping.j`
- `intl.j`: translated message templates around the formatted amount, with a
  fallback locale and a missing key ("intl: the words around the number").
  Run: `jennifer run intl.j`
- `stats.j`: mean, median, spread and robust measures of 14 days of sales
  ("stats: what a normal day looks like").
  Run: `jennifer run stats.j`
- `regression.j`: correlation and a linear regression
  ("Correlation and a straight line").
  Run: `jennifer run regression.j`
- `linalg.j`: the same fit by solving the normal equations
  ("The same fit with linalg").
  Run: `jennifer run linalg.j`
- `ml.j`: a regression with two features and a forecast
  ("ml: a second feature, and a forecast").
  Run: `jennifer run ml.j`
- `clusters.j`: scaling, k-means and k-nearest neighbours
  ("ml: clusters, then neighbours").
  Run: `jennifer run clusters.j`
- `chart.j`: writes `cones.svg`, the scatter plot with the fitted line
  ("plot: a chart as an SVG string", "The chart").
  Run: `jennifer run chart.j`, then optionally
  `rsvg-convert -w 640 cones.svg -o cones.png`
- `bars.j`: writes `week.svg`, the grouped bar chart ("Bars, grouped").
  Run: `jennifer run bars.j`
- `invoicegraph.j`: prints the invoice state machine as Graphviz DOT
  ("dot: a graph from data").
  Run: `jennifer run invoicegraph.j | dot -Tpng -o invoice.png`
  (`dot` is Graphviz, installed separately)
- `limits.j`: integer and float overflow, `sqrt` of a negative, the mean of
  an empty list, an exact `2^64` ("Strict at the boundaries").
  Run: `jennifer run limits.j`

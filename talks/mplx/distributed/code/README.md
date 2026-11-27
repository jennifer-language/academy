# Distributed computing: the code

- `cluster.j` (slides "A cluster in one process" and "The master is an
  actor"): a master that owns the queue, the leases and the result, three
  workers that pull tasks from it over a channel, one worker whose first two
  tasks fail and are queued again, and a check that the distributed result
  equals a local run. Run it with `jennifer run cluster.j`. It needs no
  network, no decks and no setup.

The framework the talk is about is
[demo-distributed](https://github.com/jennifer-language/demo-distributed); its
README walks through a cluster of one master and two workers on one machine.

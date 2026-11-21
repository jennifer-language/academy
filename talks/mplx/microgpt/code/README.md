# Build your own GPT in Jennifer: the code

The programs behind the slides. They need no server, no network and no decks,
and run with Jennifer 0.27.0 from this folder. The engine and the model are
copies of [demo-micrograd](https://github.com/jennifer-language/demo-micrograd)
(`v8/autograd.j`) and [demo-microgpt](https://github.com/jennifer-language/demo-microgpt).

- `neuron.j`: one neuron, `tanh(x * w + b)`, on the tape: prints the nodes in
  the order they were appended, runs `backward` and checks every gradient by
  hand ("Every number is a node", "The tape is already sorted").
  Run: `jennifer run neuron.j`
- `sample.j`: loads a checkpoint and generates names ("Train once, sample
  often", "Run it"). Run: `jennifer run sample.j --load 32k1000.json --samples 5`
- `train.j`: trains the GPT with Adam, one spawned worker per name in a batch,
  saves a checkpoint and samples from it ("The loss", "Training on every
  core"). It trains on `input.txt` (one name per line) when there is one, else
  on a built-in list of about 50 names, and writes `model.json` here.
  Run: `jennifer run train.j --steps 50 --batch 8 --save model.json`
- `autograd.inc.j`, `model.inc.j`, `checkpoint.inc.j`: the engine, the model
  and the checkpoint formats, included by the programs above.
- `32k1000.json`: a checkpoint trained on the 32,033 names of the makemore
  data set.

`jennifer run sample.j --help` and `jennifer run train.j --help` list every flag.

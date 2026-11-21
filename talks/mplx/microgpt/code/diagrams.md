# The talk's diagrams

The Mermaid sources of the pictures on the slides. `render-diagrams.sh` draws
each block into the PNG named in the heading above it, beside `talk.md`.

## editions.png

```mermaid
flowchart LR
  subgraph engine["demo-micrograd: one idea per edition"]
    direction TB
    subgraph a["build the engine"]
      direction LR
      v1["v1<br/>tape + backward"] --> v2["v2<br/>more ops"] --> v3["v3<br/>neuron, MLP"] --> v4["v4<br/>two moons"]
    end
    subgraph b["look at it closely"]
      direction LR
      v5["v5<br/>measure first"] --> v6["v6<br/>draw the tape"] --> v7["v7<br/>spawn"] --> v8["v8<br/>forward mode"]
    end
    a --> b
  end
  engine -- "autograd.j, verbatim" --> gpt["demo-microgpt<br/>a char-level GPT"]
```

## tape.png

```mermaid
flowchart LR
  x["#0 Leaf<br/>x = 2"] --> mul["#3 Mul<br/>-6"]
  w["#1 Leaf<br/>w = -3"] --> mul
  mul --> add["#4 Add<br/>-5"]
  b["#2 Leaf<br/>b = 1"] --> add
  add --> th["#5 Tanh<br/>-0.9999"]
```

## layout.png

```mermaid
flowchart LR
  p["#0 .. #1327: the parameters<br/>resetTo keeps them, zeroes their gradients"] --> g["#1328 ..: this step's graph<br/>embeddings, attention, MLP, loss<br/>resetTo drops it"]
```

## gpt.png

```mermaid
flowchart TB
  subgraph top[" "]
    direction LR
    subgraph emb["1. embed"]
      direction LR
      tok["token id"] --> wte["wte"] --> sum(("+"))
      pos["position"] --> wpe["wpe"] --> sum
    end
    subgraph att["2. attention + residual"]
      direction LR
      qkv["q, k, v"] --> kv["KV cache"] --> heads["2 heads"] --> wo["wo"]
    end
    emb --> att
  end
  subgraph bottom[" "]
    direction LR
    subgraph mlp["3. MLP + residual"]
      direction LR
      fc1["fc1, 32 wide"] --> relu["relu"] --> fc2["fc2"]
    end
    subgraph out["4. predict"]
      direction LR
      head["lm_head"] --> sm["softmax"] --> next["next character"]
    end
    mlp --> out
  end
  top --> bottom
```

## training.png

```mermaid
flowchart LR
  start["resetTo(numParams)"] --> s1["name 1"]
  start --> s2["name 2"]
  start --> s3["..."]
  start --> s4["name 8"]
  subgraph workers["spawn: each worker on its own copy of the tape"]
    s1
    s2
    s3
    s4
  end
  s1 --> avg["average the gradients"]
  s2 --> avg
  s3 --> avg
  s4 --> avg
  avg --> adam["Adam: update #0 .. #1327,<br/>then the next step"]
```

## checkpoint.png

```mermaid
flowchart LR
  train["train.j"] --> ck["checkpoint<br/>shape, vocabulary,<br/>1328 weights"]
  ck --> json["32k1000.json"]
  json --> sample["sample.j<br/>rebuilds the parameters<br/>in training order"]
  sample --> names["dareen, elina, arin, ..."]
```

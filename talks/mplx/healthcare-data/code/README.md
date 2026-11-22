# Code for "Healthcare data with Jennifer"

The programs behind the slides, for Jennifer 0.27.0. Run everything from
this folder. Every patient, value and identifier is invented: Jane Doe,
PAT-1001 and specimen S-2001 do not exist. Nothing here talks to a real
analyzer, LIS or FHIR server: the analyzer is `analyzer.j` and the FHIR
server is `fhirfake.j`, both on loopback.

## Setup

```sh
jvc update     # reads deck.toml: @deckyard/astm 0.2.0, fhir 0.3.0, hl7 0.2.0 into vendor/
```

The chain uses the loopback ports 4001 (ASTM), 2575 (MLLP) and 8090 (FHIR).

## Programs

| File | Shows (slides) | Run |
| --- | --- | --- |
| `sample.txt` | the analyzer's ASTM message, one record per line (3) | read by `results.j` and `analyzer.j` |
| `results.j` | parsing the records, `results`, and the error for a record before any header (4) | `jennifer run results.j` |
| `analyzer.j` | a stand-in for the instrument: sends `sample.txt` over LIS01 to 127.0.0.1:4001 (5) | started by `run.sh` |
| `lis.j` | the LIS: receives the ASTM message, maps it to an ORU^R01, sends it over MLLP and prints the acknowledgement (5, 6, 8, 9, 11) | started by `run.sh` |
| `bridge.j` | HL7 in, FHIR out: `hl7.serve`, the Patient, an Observation per OBX, one transaction (11 to 14) | started by `run.sh`; `jennifer run bridge.j [fhir-base-url]` |
| `fhirfake.j` | the FHIR server for the demo: transactions, read, search, a 404 with an OperationOutcome; prints every stored Observation (13, 16) | started by `run.sh`; `jennifer run fhirfake.j` |
| `readback.j` | `fhir.search` and the `fhir.http` error of a read (16) | run by `run.sh` at the end |
| `oru.txt` | the ORU^R01 that `lis.j` sent in one run, one segment per line (6) | read by `paths.j` |
| `paths.j` | reading with terser paths, the strict whole-field read, escapes (7, 10) | `jennifer run paths.j` |
| `run.sh` | the whole chain: fake, bridge, LIS, analyzer, then `readback.j` | `./run.sh` |

`run.sh` writes `fhirfake.log`, `bridge.log` and `lis.log`; delete them
afterwards. The fake keeps everything in memory and has no authentication.

To see the first run of slide 15, the `AE` acknowledgement, change the
`MRN` constant in `bridge.j` to `"http://example.org/fhir/mrn"` and run
`./run.sh` again: `fhir.entry` refuses the conditional URL, `hl7.serve`
answers `AE` and `lis.j` prints the reason.

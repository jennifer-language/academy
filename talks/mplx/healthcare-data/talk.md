---
theme: ivy
ratio: 16:9
transition: slide
---

# Healthcare data with Jennifer

![Jennifer](jennifer-logo.png)

A lab result on its way from the analyzer to a FHIR server: ASTM, HL7 v2 and
FHIR with the `@deckyard/astm`, `@deckyard/hl7` and `@deckyard/fhir` decks.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
Healthcare IT is three generations of standards talking to each other. This
talk follows one blood sample from the instrument that measured it to a
modern FHIR server, through four small Jennifer programs. Every patient,
number and identifier on these slides is invented: Jane Doe, born 1980, does
not exist. Every output is from a real run on a laptop, with the FHIR server
played by a fake on a loopback port. Real patient data never belongs in
slides, logs or test fixtures.
-->

---

## Three standards, one sample

```text
analyzer --ASTM E1394 over LIS01 (TCP or serial)--> LIS
LIS      --HL7 v2 ORU^R01 over MLLP-------------->  bridge
bridge   --FHIR R4 transaction over HTTPS-------->  FHIR server
```

| Program | Lines | Decks |
| --- | --- | --- |
| `analyzer.j`, a stand-in for the instrument | 16 | astm |
| `lis.j`, the laboratory information system | 76 | astm, hl7 |
| `bridge.j`, HL7 in, FHIR out | 86 | hl7, fhir |
| `fhirfake.j`, the server, for the demo only | 115 | none |

<!-- notes:
Lab analyzers speak ASTM, a record format from the 1990s, usually over a
serial cable or a TCP socket. The laboratory information system collects the
results and passes them to the hospital as HL7 version 2 messages, the
workhorse of hospital integration. Newer systems want FHIR, resources as
JSON over REST. Each hop is one program here. In a hospital the middle two
are usually one integration engine; splitting them shows each standard on
its own.
-->

---

## ASTM: records from the analyzer

```text
H|\^&|||Analyzer^A7^2.1|||||||P||20260312094500
P|1|PAT-1001|||Doe^Jane||19800214|F
O|1|S-2001||^^^GLU\^^^CREA|R||20260312080000||||X||||1||||||||||F
R|1|^^^GLU|5.4|mmol/l|3.9^6.1|N||F||auto||20260312094410|A7
R|2|^^^CREA|133|umol/l|45^90|H||F||auto||20260312094420|A7
L|1|N
```

- **H**eader, **P**atient, **O**rder, **R**esult, **C**omment, **L** terminator
- The header defines the delimiters: field `|`, repeat `\`, component `^`,
  escape `&`

<!-- notes:
One message for one specimen, every record ended by a carriage return. The
patient record carries the ID, the name and the birth date; the order names
the specimen S-2001 and the tests; each result has the test code, the value,
the units, the reference range and a flag, here N for normal and H for high.
The test codes GLU and CREA are the manufacturer's own, not a standard
vocabulary. That matters later, when we map them.
-->

---

## Reading results

```jennifer excerpt
for (def m in astm.parse($text)) {
    io.printf("from %s\n", astm.component($m.records[0], 5, 1, 1));
    for (def r in astm.results($m)) {
        io.printf("  %s %s %s: %s %s %s\n", $r.patientId, $r.sampleId,
            $r.test, $r.value, $r.units, strings.join($r.flags, ","));
    }
}
```

```text
from Analyzer
  PAT-1001 S-2001 GLU: 5.4 mmol/l N
  PAT-1001 S-2001 CREA: 133 umol/l H
astm: astm: record 1: no header before "P|1|X"
```

<!-- notes:
parse returns every message from H to L. Fields are numbered from 1 as the
standard numbers them, with the record type as field 1, so the sender's name
is component 1 of field 5 in the header. results walks the P, O, R and C
records and hands back one struct per result, with the patient and specimen
it belongs to. The last line is the deck being strict: a record before any
header is an error, not a guess.
-->

---

## The link: LIS01 over TCP

```jennifer excerpt
# analyzer.j: the instrument side
def link as astm.Link init astm.connect("127.0.0.1:4001",
    astm.instrumentProfile());
astm.send($link, astm.parse($text));

# lis.j: the computer side
def link as astm.Link init astm.accept(astm.listen("127.0.0.1:4001"),
    astm.profile());
for (def m in astm.receive($link, 30000)) { ... }
```

- ENQ, ACK, numbered frames with a checksum, EOT: `send` and `receive` do it
- A bad frame gets NAK and is sent again; a serial port: `astm.openSerial`

<!-- notes:
The low-level protocol is a polite conversation: the sender asks with ENQ,
the receiver answers ACK, then each record goes in a numbered frame with a
modulo-256 checksum, each acknowledged, and EOT ends the transmission. The
deck does all of it. The two profiles hold LIS01's timers and decide who wins
when both sides call at once: the instrument. receive returns an empty list
when nothing began in time, so a real LIS loops on it.
-->

---

## HL7 v2 in one slide

```text
MSH|^~\&|LIS||FHIRBRIDGE||20261118164607||ORU^R01|LIS00001|P|2.5.1
PID|1||PAT-1001||Doe^Jane||19800214|F
OBR|1||S-2001
OBX|1|NM|14749-6^Glucose [Moles/volume] in Serum or Plasma^LN||5.4|...
```

| Path | Value |
| --- | --- |
| `MSH-9-1` | `ORU`, an observation result |
| `PID-5-1`, `PID-5-2` | `Doe`, `Jane` |
| `OBX(2)-5` | `133`, the second OBX's value |

<!-- notes:
HL7 version 2 looks like ASTM's cousin, and it is: segments instead of
records, a three-letter ID first, then fields split by bars, components by
carets, repetitions by tildes. MSH, the header, declares the delimiters in
its first two fields, carries the message type ORU^R01 and a control ID that
the acknowledgement will quote. The terser paths in the table are how the deck
reads a value: segment, optional repetition in brackets, field, component.
-->

---

## Reading with paths, strictly

```jennifer excerpt
def m as hl7.Message init hl7.parse($text);
io.printf("%s, %s\n", hl7.get($m, "PID-5-1"), hl7.get($m, "PID-5-2"));
io.printf("%s %s\n", hl7.get($m, "OBX(2)-3-1"), hl7.get($m, "OBX(2)-5"));
hl7.get($m, "PID-5");   # throws
```

```text
Doe, Jane
14682-9 133
hl7: PID-5 has repetitions, components or subcomponents: "Doe^Jane"
```

<!-- notes:
get unescapes the value it returns. Asking for a whole field that has
components is an error, because flattening Doe^Jane into one string would
lose the structure silently; read the components, or use raw for the wire
text. The same strictness runs through all three decks: malformed input is
an error, never a guess. In healthcare a guess can put a value on the wrong
patient, and an error is the one you can see and fix.
-->

---

## Mapping ASTM to HL7

| ASTM | HL7 v2 | Note |
| --- | --- | --- |
| P-3 patient ID | PID-3 | the lab's ID, here an MRN |
| P-6 name | PID-5 | family, given |
| P-8, P-9 | PID-7, PID-8 | birth date, sex |
| O-3 specimen | OBR-3 | the filler's specimen number |
| R-3 `GLU` | OBX-3 `14749-6^...^LN` | instrument code to **LOINC** |
| R-4, R-5 | OBX-5, OBX-6 | value; unit to **UCUM**: `mmol/l` to `mmol/L` |
| R-6, R-7 | OBX-7, OBX-8 | range, flag |
| R-13 | OBX-14 | time of the observation |

<!-- notes:
Most fields move one to one; the interesting rows are the codes. GLU means
glucose only to this analyzer. LOINC is the shared vocabulary for lab tests,
and the code has to match what was measured: 14749-6 is glucose in moles per
volume, which fits mmol/L, while the familiar 2345-7 is mass per volume, for
mg/dL. Units go to UCUM, which is case-sensitive. In a real lab this table is
reviewed and signed off; it is the part where errors hurt.
-->

---

## Building the ORU^R01

```jennifer excerpt
def const TESTS as map of string to list of string init {
    "GLU": ["14749-6", "Glucose [Moles/volume] in Serum or Plasma", "mmol/L"],
    "CREA": ["14682-9", "Creatinine [Moles/volume] in S...", "umol/L"]
};
def oru as hl7.Message init hl7.newMessage("ORU", "R01", $id, "2.5.1");
def t as list of string init TESTS[$r.test];   # a missing key throws
def obx as hl7.Segment init hl7.segment("OBX", $oru.delimiters);
$obx = hl7.setComponent($obx, 3, 1, 1, $t[0]);   # and 3-2, 3-3 "LN"
$obx = hl7.setField($obx, 5, $r.value);
$oru = hl7.addSegment($oru, $obx);
```

<!-- notes:
newMessage writes the MSH with the time, the type, the control ID and the
version. Segments are values: every set returns a new segment and
addSegment a new message, so a half-built message never leaks out. Reading a
map key that is not there throws, which is exactly right for an unknown test
code: the message is refused instead of going out with a wrong code. The
whole toOru function is about forty lines, one setField per mapped field.
-->

---

## Escapes are not optional

```jennifer excerpt
def nte as hl7.Segment init hl7.setField(
    hl7.segment("NTE", $m.delimiters), 3, "fasting & 8 h, see ^ note");
io.printf("%s\n%s\n", hl7.encodeSegment($nte), hl7.field($nte, 3));
```

```text
NTE|||fasting \T\ 8 h, see \S\ note
fasting & 8 h, see ^ note
```

<!-- notes:
Free text from a person contains the delimiters sooner or later: an
ampersand in a comment, a caret in a name. Written raw it would split the
field and shift every value after it. The set functions escape every
delimiter and control character, the read functions unescape, and parse
checks every escape sequence, so a message the deck accepts encodes back. A
CR inside a value can never start a new segment: that would be an injection.
-->

---

## MLLP: send, acknowledge, refuse

```jennifer excerpt
# lis.j
def mllp as hl7.Connection init hl7.connect("127.0.0.1:2575", hl7.options());
def ack as hl7.Message init hl7.send($mllp, $oru);
io.printf("ack: %s %s\n", hl7.get($ack, "MSA-1"), hl7.get($ack, "MSA-3"));

# bridge.j
func onMessage(m as hl7.Message) {
    ...   # to FHIR, see the next slides
    return hl7.ack($m, "AA", "", "ACK" + hl7.get($m, "MSH-10"));
}
hl7.serve(hl7.listen("127.0.0.1:2575"), hl7.options(), onMessage);
```

<!-- notes:
MLLP wraps each message in a start byte and two end bytes over TCP. send
waits for the acknowledgement, checks that MSA-2 quotes our control ID, and
sends again when none comes within thirty seconds. serve gives each client a
task and returns the handler's message as the reply. The LIS printed ack: AA,
which means accepted. A handler that throws is answered with AE and the
error text, so the sender always learns why; we see one in a moment. MLLP has no encryption: keep it on
a trusted network or in a tunnel.
-->

---

## FHIR: the Patient from PID

```jennifer excerpt
def p as json.Value init json.map({"resourceType": "Patient"});
$p = json.set($p, "/identifier",
    json.list([fhir.identifier(MRN, hl7.get($m, "PID-3-1"))]));
def name as json.Value init json.map({"family": hl7.get($m, "PID-5-1")});
$name = json.set($name, "/given", json.list([hl7.get($m, "PID-5-2")]));
$p = json.set($p, "/name", json.list([$name]));
$p = json.set($p, "/birthDate", fhirDate(hl7.get($m, "PID-7")));
$p = json.set($p, "/gender", $sex[hl7.get($m, "PID-8")]);   # F -> female
```

<!-- notes:
FHIR resources are JSON, and the deck keeps them as json.Value: it adds
helpers for the pieces every resource has, identifiers, codings and
references, and leaves the rest to you. json.set never changes its argument,
it returns the new document. An identifier needs a system, a URI that says
whose numbers these are; MRN is a constant, the hospital's. fhirDate is a
short helper that turns 19800214 into 1980-02-14, the FHIR form.
-->

---

## FHIR: an Observation per OBX

```jennifer excerpt
$o = json.set($o, "/code", fhir.concept(LOINC,
    hl7.component($obx, 3, 1, 1), hl7.component($obx, 3, 1, 2)));
$o = json.set($o, "/subject", json.map({"reference": $subject}));
def q as json.Value init json.map(
    {"unit": $unit, "system": UCUM, "code": $unit});
$q = json.set($q, "/value", convert.toFloat(hl7.field($obx, 5)));
$o = json.set($o, "/valueQuantity", $q);
```

```text
"code": {"coding": [{"system": "http://loinc.org", "code": "14682-9", ...
"valueQuantity": {"unit": "umol/L", "system": "http://unitsofmeasure.org", ...
"interpretation": [{"coding": [{"system": ".../v3-ObservationInterpretation", ...
```

<!-- notes:
concept builds a CodeableConcept with one coding: the LOINC system, the
code, the display text. The quantity carries the unit twice, once for people
and once as a UCUM code for machines. The H flag becomes an interpretation
from HL7's terminology; the reference range would go into referenceRange in
the same way. The output is from the server's copy, shortened. A real system
also sets the category to laboratory, which is left out here.
-->

---

## One transaction, all or nothing

```jennifer excerpt
def pid as string init "urn:uuid:" + uuid.v4();
def b as json.Value init fhir.bundle("transaction");
$b = fhir.entry($b, "PUT", "Patient?identifier={MRN}|{$mrn}",
    patientFrom($m), $pid);
for (def obx in hl7.segmentsOf($m, "OBX")) {
    $b = fhir.entry($b, "POST", "Observation", observationFrom($obx, $pid), "");
}
def result as json.Value init fhir.transaction($c, $b);
```

```text
bridge: LIS00001 -> 3 FHIR entries
```

<!-- notes:
The patient and the observations go in one transaction bundle, so the server
stores all of them or none. The Observations point at the patient through a
temporary urn:uuid, which the server replaces with the real id. The patient
entry is a conditional update: PUT with a search URL creates the patient on
the first result and finds the same one on every later result, so the
patient is not duplicated. entry checks every entry before anything is sent.
-->

---

## The first run said AE

```text
ack: AE fhir: an entry URL is relative to the base, such as Patient/123,
got "Patient?identifier=http://example.org/fhir/mrn|PAT-1001"
```

```jennifer excerpt
def const MRN as string init "urn:oid:2.999.1.1";   # was http://example.org/...
```

- `fhir.entry` refuses `://` in an entry URL, conditional ones included
- `serve` turned the throw into an `AE` acknowledgement: nothing was lost
- An OID system (`2.999` is the arc for examples) fits in the URL as is

<!-- notes:
This is the real first run. The identifier system was an http URL, and the
deck refuses anything in an entry URL that looks absolute, to keep requests
on the server. The handler threw, serve answered AE with the reason, and the
LIS printed it; the message is still the LIS's to resend. Many hospitals use
OIDs for their identifier systems anyway. Percent-encoding the URL system in
the search would be the other way out.
-->

---

## Reading it back, and a 404

```jennifer excerpt
def c as fhir.Client init fhir.client("http://127.0.0.1:8090/fhir");
for (def o in fhir.search($c, "Observation", ["subject=Patient/1"])) { ... }
try {
    fhir.read($c, "Patient", "999");
} catch (e) {
    if ($e.kind == "fhir.http") {
        io.printf("%d %s: %s\n", $e.status, $e.issues[0].code,
            $e.issues[0].diagnostics);
    }
}
```

```text
404 not-found: Resource Patient/999 is not known
```

<!-- notes:
search follows the server's next links through every page, up to a page and
a byte limit, and returns the resources: here the two Observations, 14749-6
at 5.4 mmol/L and 14682-9 at 133 umol/L. A refused request throws an
HttpError struct of kind fhir.http, with the status and the server's
OperationOutcome issues as fields, so the code reads the issue code instead
of parsing a message. Check the kind first, then read the fields. Plain http
is only allowed to this machine; anything else needs https or an explicit
withPlainHttp.
-->

---

## Before this goes near a real patient

- **Synthetic data** in tests, slides and logs; log control IDs, not names
- **Transport:** MLLP in a tunnel or VPN; FHIR over https with
  `fhir.withToken` or `fhir.smartBackend` (SMART backend services)
- **Mapping:** reviewed code tables, UCUM units, time zones in every
  timestamp (`ZONE` is a constant here)
- **Retries are safe:** control IDs for HL7, a conditional PUT for the patient
- **Strict parsing** in all three decks: refuse, report, never guess

<!-- notes:
The demo cuts corners that a production interface must not. The FHIR fake
has no authentication; a real server wants a bearer token, and the deck
implements SMART backend services with a signed client assertion for
server-to-server access. Lab timestamps usually come without a zone, so the
bridge has to know the lab's. And every hop must survive being repeated,
because every hop retries: an Observation posted twice is a duplicate result.
-->

---

## Read more

- [deckyard/deck-astm](https://registry.jennifer-lang.dev/deck/deckyard/astm): records,
  results, orders, host queries, the link
- [deckyard/deck-hl7](https://registry.jennifer-lang.dev/deck/deckyard/hl7): paths, escapes,
  character sets, acknowledgements, MLLP
- [deckyard/deck-fhir](https://registry.jennifer-lang.dev/deck/deckyard/fhir): read, search,
  write, transactions, operations, SMART
- The language: [jennifer-lang.dev](https://jennifer-lang.dev/), more talks
  in the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.27.0, November 2026.

<!-- notes:
Each deck's manual has a guide per layer and a cheatsheet of every function.
Things this talk left out: ASTM host queries, where the analyzer asks the
LIS what to run on a barcode; HL7 character sets in MSH-18 for names with
accents; FHIR history, patch and operations. A good exercise is the way back:
an HL7 order message from a FHIR ServiceRequest, sent to the LIS, ending as
an ASTM order record for the analyzer.
-->
